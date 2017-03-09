#!/bin/bash -xe

package="opencv"

pushd `dirname $0` > /dev/null
myDir=`pwd`
popd > /dev/null

localRepoDir="${myDir}/build_artefacts"

logsDir="${localRepoDir}/build_logs"
mkdir -p "${logsDir}"

cd ${myDir}

# Build metapackages only tracking the features
conda build ${package}-turbo-feature \
      --output-folder ${localRepoDir} \
      &> >(tee ${logsDir}/${package}-turbo-feature.log)

conda build ${package}-cuda-feature \
      --output-folder ${localRepoDir} \
      &> >(tee ${logsDir}/${package}-cuda-feature.log)

# Rerender the main recipe
conda-smithy rerender &> >(tee ${logsDir}/conda-smithy-rerender.log)

# Build the main package
dockerScript="${myDir}/ci_support/run_docker_build.sh"
${dockerScript} &> >(tee ${logsDir}/${package}.log)

# Build the metapackages tracking the features and installing the main package
conda build ${package}-turbo \
      --output-folder ${localRepoDir} \
      --channel file://${localRepoDir} \
      &> >(tee ${logsDir}/${package}-turbo.log)

conda build ${package}-turbo-cuda \
      --output-folder ${localRepoDir} \
      --channel file://${localRepoDir} \
      &> >(tee ${logsDir}/${package}-turbo-cuda.log)

# Fertig
set +x
echo "All done, please upload the new artifacts in ${localRepoDir} to anaconda.org like:"
echo "  " `cat ${logsDir}/${package}-turbo-feature.log | grep "anaconda upload"`
echo "  " `cat ${logsDir}/${package}-cuda-feature.log | grep "anaconda upload"`
echo "  " `cat ${logsDir}/${package}.log | grep "anaconda upload"`
echo "  " `cat ${logsDir}/${package}-turbo.log | grep "anaconda upload"`
echo "  " `cat ${logsDir}/${package}-turbo-cuda.log | grep "anaconda upload"`
echo "add \"-u {channel}\" to upload to a different organization (e.g. \"-u loopbio\")."
echo "
--- Fertig ---
"
