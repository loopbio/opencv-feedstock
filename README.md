About opencv
============

Home: http://opencv.org/

Package license: BSD 3-clause

Feedstock license: BSD 3-Clause

Summary: Loopbio optimized OpenCV builds: https://github.com/loopbio/opencv-feedstock



Current build status
====================

[![Linux](https://img.shields.io/circleci/project/github/loopbio/opencv-vanilla-feedstock/master.svg?label=Linux)](https://circleci.com/gh/loopbio/opencv-vanilla-feedstock)
![OSX disabled](https://img.shields.io/badge/OSX-disabled-lightgrey.svg)
![Windows disabled](https://img.shields.io/badge/Windows-disabled-lightgrey.svg)

Current release info
====================

| Name | Downloads | Version | Platforms |
| --- | --- | --- | --- |
| [![Conda Recipe](https://img.shields.io/badge/recipe-opencv-green.svg)](https://anaconda.org/loopbio/opencv) | [![Conda Downloads](https://img.shields.io/conda/dn/loopbio/opencv.svg)](https://anaconda.org/loopbio/opencv) | [![Conda Version](https://img.shields.io/conda/vn/loopbio/opencv.svg)](https://anaconda.org/loopbio/opencv) | [![Conda Platforms](https://img.shields.io/conda/pn/loopbio/opencv.svg)](https://anaconda.org/loopbio/opencv) |

Installing opencv
=================

Installing `opencv` from the `loopbio` channel can be achieved by adding `loopbio` to your channels with:

```
conda config --add channels loopbio
```

Once the `loopbio` channel has been enabled, `opencv` can be installed with:

```
conda install opencv
```

It is possible to list all of the versions of `opencv` available on your platform with:

```
conda search opencv --channel loopbio
```




Updating opencv-feedstock
=========================

If you would like to improve the opencv recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`loopbio` channel, whereupon the built conda packages will be available for
everybody to install and use from the `loopbio` channel.
Note that all branches in the loopbio/opencv-feedstock are
immediately built and any created packages are uploaded, so PRs should be based
on branches in forks and branches in the main repository should only be used to
build distinct package versions.

In order to produce a uniquely identifiable distribution:
 * If the version of a package **is not** being increased, please add or increase
   the [``build/number``](http://conda.pydata.org/docs/building/meta-yaml.html#build-number-and-string).
 * If the version of a package **is** being increased, please remember to return
   the [``build/number``](http://conda.pydata.org/docs/building/meta-yaml.html#build-number-and-string)
   back to 0.