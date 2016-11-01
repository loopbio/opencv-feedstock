About opencv
============

Home: http://opencv.org/

Package license: BSD 3-clause

Feedstock license: BSD 3-Clause

Summary: Computer vision and machine learning software library.



Installing opencv
=================

Installing `opencv` from the `sdvillal` channel can be achieved by adding `sdvillal` to your channels with:

```
conda config --add channels sdvillal
```

Once the `sdvillal` channel has been enabled, `opencv` can be installed with:

```
conda install opencv
```

It is possible to list all of the versions of `opencv` available on your platform with:

```
conda search opencv --channel sdvillal
```



Current build status
====================

Linux: [![Circle CI](https://circleci.com/gh/conda-forge/opencv-feedstock.svg?style=shield)](https://circleci.com/gh/conda-forge/opencv-feedstock)
OSX: ![](https://cdn.rawgit.com/conda-forge/conda-smithy/90845bba35bec53edac7a16638aa4d77217a3713/conda_smithy/static/disabled.svg)
Windows: ![](https://cdn.rawgit.com/conda-forge/conda-smithy/90845bba35bec53edac7a16638aa4d77217a3713/conda_smithy/static/disabled.svg)

Current release info
====================
Version: [![Anaconda-Server Badge](https://anaconda.org/sdvillal/opencv/badges/version.svg)](https://anaconda.org/sdvillal/opencv)
Downloads: [![Anaconda-Server Badge](https://anaconda.org/sdvillal/opencv/badges/downloads.svg)](https://anaconda.org/sdvillal/opencv)


Updating opencv-feedstock
=========================

If you would like to improve the opencv recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`sdvillal` channel, whereupon the built conda packages will be available for
everybody to install and use from the `sdvillal` channel.
Note that all branches in the conda-forge/opencv-feedstock are
immediately built and any created packages are uploaded, so PRs should be based
on branches in forks and branches in the main repository should only be used to
build distinct package versions.

In order to produce a uniquely identifiable distribution:
 * If the version of a package **is not** being increased, please add or increase
   the [``build/number``](http://conda.pydata.org/docs/building/meta-yaml.html#build-number-and-string).
 * If the version of a package **is** being increased, please remember to return
   the [``build/number``](http://conda.pydata.org/docs/building/meta-yaml.html#build-number-and-string)
   back to 0.
