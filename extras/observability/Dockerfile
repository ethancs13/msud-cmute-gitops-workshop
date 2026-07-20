FROM eclipse-temurin:21-jre

RUN apt-get update && apt-get install -y curl jq

RUN useradd -m -d /server minecraft
WORKDIR /server
USER minecraft

ARG PAPER_VERSION=1.21.11
ARG PAPER_BUILD=69
RUN DOWNLOAD_URL=$(curl -s -H "User-Agent: msud-workshop-student (https://github.com/msu-denver)" \
      "https://fill.papermc.io/v3/projects/paper/versions/${PAPER_VERSION}/builds" \
      | jq -r --argjson build "${PAPER_BUILD}" 'first(.[] | select(.id == $build)) | .downloads."server:default".url') \
    && echo "Downloading: ${DOWNLOAD_URL}" \
    && curl -fo paper.jar -H "User-Agent: msud-workshop-student (https://github.com/msu-denver)" "${DOWNLOAD_URL}"

# Exposes on: localhost:9940/metrics
RUN mkdir -p plugins && \
    curl -fL -o plugins/prometheus-exporter.jar \
    https://github.com/sladkoff/minecraft-prometheus-exporter/releases/download/v3.1.2/minecraft-prometheus-exporter-3.1.2.jar

RUN echo "eula=true" > eula.txt

EXPOSE 25565 9940
CMD ["java", "-Xms1G", "-Xmx2G", "-jar", "paper.jar", "--nogui"]