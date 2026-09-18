#! /bin/bash -e
# script to run NERVE standalone trough docker

# Tag, not digest: verify_base.sh checks it against the lock, and archive-restored images have no digest.
PSORT_IMAGE="francecosta/psortb_http_api:v0.0.1"
NERVE_VERSION="v0.0.9"
NERVE_DIR="$(cd "$(dirname "$0")" && pwd)"
NERVE_COMMIT="$(git -C "$NERVE_DIR" rev-parse HEAD 2>/dev/null || printf unknown)"

# create network
[ ! "$(docker network ls | grep nerve-network)" ] && docker network create nerve-network --attachable

# run psortb container if not alredy running
[ ! "$(docker ps -q --filter name=^/psortb$)" ] && docker run --rm -p 8080:8080 --network nerve-network --name psortb -d "$PSORT_IMAGE"

# Always build: a pre-existing tag is not evidence of what it contains.
docker build --build-arg NERVE_COMMIT="$NERVE_COMMIT" -t nerve:$NERVE_VERSION "$NERVE_DIR"

# run nerve container
docker run --network nerve-network -p 8880:8880 -it -v $(pwd):/workdir nerve:$NERVE_VERSION "$@"
