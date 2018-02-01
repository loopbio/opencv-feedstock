import tempfile
import os.path as op
import platform
import shutil
import subprocess
import requests
import cv2
import pprint
import random
import json
from functools import partial
from hashlib import sha256
import pytest


# --- A watered-down video reader abstraction + a simple implementation on top of opencv
# Add other implementations as you see fit and include them in the video_reader fixture.

class VideoReader(object):

    def __init__(self, path):
        super(VideoReader, self).__init__()
        self.path = path

    @property
    def next_frame_num(self):
        raise NotImplementedError

    @property
    def num_frames(self):
        raise NotImplementedError()

    @property
    def width(self):
        raise NotImplementedError()

    @property
    def height(self):
        raise NotImplementedError()

    @property
    def fps(self):
        raise NotImplementedError()

    @property
    def image_shape(self):
        return self.height, self.width

    @property
    def image_size(self):
        return self.width, self.height

    def next_frame(self):
        raise NotImplementedError()

    def seek(self, frame_num):
        raise NotImplementedError()

    def frame(self, frame_num):
        self.seek(frame_num)
        read_frame_num, image = self.next_frame()
        assert frame_num == read_frame_num
        return image

    def close(self):
        raise NotImplementedError()

    def __iter__(self):
        while self.next_frame_num < self.num_frames:
            yield self.next_frame()

    def __getitem__(self, item):
        # Missing correct handling of slices + numpy fancy indexing, maybe lazy, maybe ala slicerator
        return self.frame(item)

    def __len__(self):
        return self.num_frames

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


class OpenCVIsNotForVideo(Exception):
    pass


class OpenCVVideoReader(VideoReader):

    def __init__(self, path, seek_when='never', double_check_seek=True):
        super(OpenCVVideoReader, self).__init__(path)
        self._next_frame_num = 0
        self._handle = None
        self._seek_when = seek_when
        self._num_frames = None
        self._double_check_seek = double_check_seek

    @property
    def next_frame_num(self):
        return self._next_frame_num

    @property
    def num_frames(self):
        if self._num_frames is None:
            try:
                ffprobe_command = ('ffprobe -v error -count_frames -select_streams v:0 '
                                   '-show_entries stream=nb_read_frames '
                                   '-of default=nokey=1:noprint_wrappers=1').split()
                self._num_frames = int(subprocess.check_output(ffprobe_command + [self.path]).strip())
            except Exception:
                # This is known to be *very* buggy...
                print('WARNING: using opencv to infer a likely wrong frame count')
                self._num_frames = self._cap.get(cv2.CAP_PROP_FRAME_COUNT)
        return self._num_frames

    @property
    def fps(self):
        return self._cap.get(cv2.CAP_PROP_FPS)

    @property
    def width(self):
        return self._cap.get(cv2.CAP_PROP_FRAME_WIDTH)

    @property
    def height(self):
        return self._cap.get(cv2.CAP_PROP_FRAME_HEIGHT)

    def next_frame(self):
        ret, image = self._cap.read()
        if not ret:
            raise OpenCVIsNotForVideo('OpenCV cannot read frame %d from video %s with length %d' %
                                      (self._next_frame_num, self.path, len(self)))
        self._next_frame_num += 1
        return self.next_frame_num - 1, image

    @property
    def seek_when(self):
        return self._seek_when

    @seek_when.setter
    def seek_when(self, seek_mode):
        valid_modes = ('never', 'always')
        if isinstance(seek_mode, int) and seek_mode > 0 or seek_mode in valid_modes:
            self._seek_when = seek_mode
        raise ValueError('Unknown seek mode %r; must be a non-negative integer or one of %r' % valid_modes)

    def seek(self, frame_num):

        # Will we use opencv seeking?
        if isinstance(self._seek_when, int):
            must_seek = (frame_num - self.next_frame_num) >= self._seek_when
        else:
            must_seek = self._seek_when == 'always' and frame_num != self.next_frame_num

        # Actually put the reader before the
        if must_seek:
            self._cap.set(cv2.CAP_PROP_POS_FRAMES, frame_num)
            self._next_frame_num = frame_num
        else:
            # Go back to frame 0;
            # perhaps seeking to 0 instead of closing and reopening would be faster
            # but let's not support bizarre access patterns
            if self.next_frame_num > frame_num:
                self.close()
            while self.next_frame_num < frame_num:
                self.next_frame()

        # Is opencv tricking us once again?
        if self._double_check_seek:
            if self._cap.get(cv2.CAP_PROP_POS_FRAMES) != frame_num:
                raise OpenCVIsNotForVideo(
                    'OpenCV reports the current position is at a frame (%d) different than ours (%d)' % (
                        self._cap.get(cv2.CAP_PROP_POS_FRAMES), frame_num))

    @property
    def _cap(self):
        if self._handle is None or not self._handle.isOpened():
            self.close()
            self._handle = cv2.VideoCapture(self.path)
            if not self._handle.isOpened():
                raise OpenCVIsNotForVideo('OpenCV cannot open video: ', self.path)
        return self._handle

    def close(self):
        if self._handle is not None:
            self._handle.release()
            self._handle = None
            self._num_frames = None
            self._next_frame_num = 0


# --- Fixtures

def download_video(video_url, video_path=None):
    if video_path is None:
        temp_dir = tempfile.mkdtemp(prefix='downloaded-video')
        video_path = op.join(temp_dir, op.basename(video_url))
    req = requests.get(video_url, stream=True)
    with open(video_path, 'wb') as f:
        shutil.copyfileobj(req.raw, f)
    return video_path


def hash_image(image):
    return sha256(image.data).hexdigest()


def compute_video_seek_expectations(video_path,
                                    video_reader=partial(OpenCVVideoReader, seek_when='never'),
                                    frame_numbers=None, remove_file=None,
                                    fail_if_error=False):
    frames_shas = {}

    if isinstance(frame_numbers, int):
        frame_numbers = range(frame_numbers)

    try:
        if not op.isfile(video_path):
            video_path = download_video(video_path)
            if remove_file is None:
                remove_file = True

        with video_reader(video_path) as reader:
            # Assume *no seeking* is always correct
            # Otherwise, abstract the video reader here and use another trustworthy lib to read
            # (or generate the videos with known ground truth, see e.g. codebar from J)

            if frame_numbers is None:
                frame_numbers = range(len(reader))
            else:
                frame_numbers = range(min(max(frame_numbers) + 1, len(reader)))

            for frame_num in frame_numbers:
                try:
                    _, image = reader.next_frame()
                except Exception as ex:
                    if not fail_if_error:
                        # These lying frame count estimations...
                        print('WARNING: could not read all frames')
                        print(str(ex))
                        print('Any other frame will be ignored')
                        break
                    else:
                        raise
                if frame_num in frame_numbers:
                    frames_shas[frame_num] = hash_image(image)
    finally:
        if remove_file and video_path:
            shutil.rmtree(op.dirname(video_path), ignore_errors=True)
    return frames_shas


def opencv_test_video_url(video_fn):
    OPENCV_TEST_VIDEOS_URL = 'https://github.com/opencv/opencv_extra/raw/master/testdata/highgui/video/'
    return OPENCV_TEST_VIDEOS_URL + video_fn


def opencv_seek_ground_truths(use_cache=True, recompute=False, do_print=False):

    OPENCV_TEST_VIDEOS = tuple(map(opencv_test_video_url, [
        'VID00003-20100701-2204.3GP',
        'VID00003-20100701-2204.avi',
        'VID00003-20100701-2204.mpg',
        'VID00003-20100701-2204.wmv',
        'big_buck_bunny.avi',
        'big_buck_bunny.mjpg.avi',
        'big_buck_bunny.mov',
        'big_buck_bunny.mp4',
        'big_buck_bunny.mpg',
        'big_buck_bunny.wmv',
        'sample_sorenson.avi',
        'sample_sorenson.mov',
        'sample_sorenson.wmv',
    ]))

    cache_json = op.join(op.dirname(__file__), 'opencv_frame_hashes.json')

    if not use_cache or recompute or not op.isfile(cache_json):
        # noinspection PyTypeChecker
        video_expectations = {
            op.basename(video): compute_video_seek_expectations(video, frame_numbers=None)
            for video in OPENCV_TEST_VIDEOS
        }
        if use_cache:
            with open(cache_json, 'wt') as writer:
                json.dump(video_expectations, writer)
    else:
        # N.B. hardcoding this assumes video decompression is always bit accurate,
        # which might not be true for different decompression libs / versions.
        # This allows to catch when differences happen.
        with open(cache_json, 'rt') as reader:
            video_expectations = {video_name: {int(frame_num): frame_hash
                                               for frame_num, frame_hash in video_hashes.items()}
                                  for video_name, video_hashes in json.load(reader).items()}

    if do_print:
        pprint.pprint(video_expectations)

    return video_expectations


# opencv_seek_ground_truths(use_cache=True, recompute=True, do_print=True)
# exit(0)

# In general, opencv here means opencv VideoCapture with ffmpeg backend
readers_to_test = [
    (partial(OpenCVVideoReader, seek_when='never', double_check_seek=False), 'opencv-never-seek'),
    (partial(OpenCVVideoReader, seek_when='always', double_check_seek=False), 'opencv-always-seek'),
    (partial(OpenCVVideoReader, seek_when=10, double_check_seek=False), 'opencv-10orbigger-seek')
]


@pytest.fixture(params=[reader for reader, reader_id in readers_to_test],
                ids=[reader_id for reader, reader_id in readers_to_test])
def video_reader(request):
    return request.param


_PRECOMPUTED_OPENCV_SEEK_EXPECTATIONS = opencv_seek_ground_truths(recompute=False, do_print=False)


@pytest.fixture(params=sorted(_PRECOMPUTED_OPENCV_SEEK_EXPECTATIONS), scope='module')
def video_path(request):
    # Beware: downloads the video; ensure it happens only once.
    video_fn = request.param
    temp_dir = tempfile.mkdtemp(prefix='downloaded-video')
    video_path = download_video(opencv_test_video_url(video_fn), op.join(temp_dir, video_fn))
    yield video_path
    shutil.rmtree(op.dirname(video_path), ignore_errors=True)


@pytest.fixture(params=(True, False), ids=['expectations=precomputed', 'expectations=online'])
def use_precomputed_expectations(request):
    return request.param


@pytest.fixture
def seek_expectations(video_path, use_precomputed_expectations):
    if use_precomputed_expectations:
        yield video_path, _PRECOMPUTED_OPENCV_SEEK_EXPECTATIONS[op.basename(video_path)]
    else:
        yield video_path, compute_video_seek_expectations(video_path, remove_file=False, fail_if_error=False)


@pytest.mark.skipif(platform.system() == 'Windows',
                    reason='FFMPEG currently not built on Windows')
def test_seeking(request, seek_expectations, video_reader):
    # Some recent fun with opencv and seeking: https://github.com/opencv/opencv/issues/9053

    # Some of these seekings are known to be wrong;
    # pytest will actually fail if these get fixed, so we can update the test
    KNOWN_PROBLEMS = (
        # A few frames off
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.3GP-expectations=precomputed]',
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.3GP-expectations=online]',
        'test_seeking[opencv-10orbigger-seek-VID00003-20100701-2204.3GP-expectations=precomputed]',
        'test_seeking[opencv-10orbigger-seek-VID00003-20100701-2204.3GP-expectations=online]',

        # A lot of frames off
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.avi-expectations=precomputed]',
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.avi-expectations=online]',
        'test_seeking[opencv-10orbigger-seek-VID00003-20100701-2204.avi-expectations=precomputed]',
        'test_seeking[opencv-10orbigger-seek-VID00003-20100701-2204.avi-expectations=online]',

        # A few frames off
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.mpg-expectations=precomputed]',
        'test_seeking[opencv-always-seek-VID00003-20100701-2204.mpg-expectations=online]',

        # A few frames off
        'test_seeking[opencv-always-seek-big_buck_bunny.mpg-expectations=precomputed]',
        'test_seeking[opencv-always-seek-big_buck_bunny.mpg-expectations=online]',
        'test_seeking[opencv-10orbigger-seek-big_buck_bunny.mpg-expectations=precomputed]',
        'test_seeking[opencv-10orbigger-seek-big_buck_bunny.mpg-expectations=online]',
    )
    is_known_problem = request.node.name in KNOWN_PROBLEMS

    # Seek expectations for the video
    video_path, seek_expectations = seek_expectations
    if not seek_expectations:
        seek_expectations = compute_video_seek_expectations(video_path, remove_file=False, fail_if_error=True)
    first_frame, last_frame = min(seek_expectations), max(seek_expectations)
    hash2frame = {v: k for k, v in seek_expectations.items()}

    # Sometimes it takes a bit to uncover errors...
    # Increase these to make tests more strict
    num_repetitions = 10
    num_frames_per_repetition = 20

    with video_reader(video_path) as reader:
        for rng_seed in range(num_repetitions):
            # Randomize our selection of frames
            frame2hash = list(seek_expectations.items())
            random.Random(rng_seed).shuffle(frame2hash)
            frame2hash = frame2hash[:num_frames_per_repetition]
            # Always include "border" frames in the first experiment
            if 0 == rng_seed:
                frame2hash += [(first_frame, seek_expectations[first_frame]),
                               (last_frame, seek_expectations[last_frame])]
            for frame_num, frame_hash in frame2hash:
                grabbed_image_hash = hash_image(reader.frame(frame_num))
                test_pass = grabbed_image_hash == frame_hash
                if not test_pass:
                    actual_frame_num = hash2frame.get(grabbed_image_hash)
                    if actual_frame_num is None:
                        message = ('image for frame %d generates an unknown hash (%r)' %
                                   (frame_num, request.node.name))
                    else:
                        message = ('wrong seek for frame %d (went to %d) (%r)' %
                                   (frame_num, actual_frame_num, request.node.name))
                    if is_known_problem:
                        pytest.xfail('Known seeking error for %r: %r' % (request.node.name, message))
                    assert False, message
            # everything passed, should it not?
            assert not is_known_problem, ('problem for %r seems fixed, remove from known problems' %
                                          request.node.name)


if __name__ == '__main__':
    pytest.main(__file__)

# We could also add some benchmark fixtures here and there, or even better, bring John's benchmarks into building

#
# Unfortunately PyAV seems a bit dead:
#   https://github.com/mikeboers/PyAV
#
# ffpyplayer looks nice too, and perhaps we can just implement a frame-precise seek on top of it:
#   https://github.com/matham/ffpyplayer
#
# or we can just stick to our pims-inspired PyAVReader (then we need to look for better performance)
#
# It is a shame we cannot trust ffmpeg seek to be frame accurate with all codec + container,
# even if they say so: http://trac.ffmpeg.org/wiki/Seeking. For each (wrapper) library
#
