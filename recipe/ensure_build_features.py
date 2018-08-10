from __future__ import print_function, division
import cv2


def cv2_build_info():
    build_infos = {}
    context_stack = []
    for line in cv2.getBuildInformation().splitlines():
        if ':' in line:
            level = len(line) - len(line.lstrip())
            key, _, value = line.partition(':')
            while context_stack and level <= context_stack[-1][0]:
                context_stack.pop()
            context_stack.append((level, key.strip()))
            print(key, context_stack)
            build_infos['_'.join(key for _, key in context_stack)] = value.strip()
    return build_infos


info = cv2_build_info()
assert 'TBB' in info['Parallel framework']
