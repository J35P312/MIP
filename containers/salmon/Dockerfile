################## BASE IMAGE ######################

FROM clinicalgenomics/mip:2.0

################## METADATA ######################

LABEL base_image="clinicalgenomics/mip:2.0"
LABEL version="1"
LABEL software="salmon"
LABEL software.version="0.12.0"
LABEL extra.binaries="salmon"
LABEL maintainer="Clinical-Genomics/MIP"

RUN conda install salmon=0.12.0

## Clean up after conda
RUN /opt/conda/bin/conda clean -ya

WORKDIR /data/
