FROM openvino/model_server:2026.4.1-gpu

EXPOSE 8000

ENTRYPOINT ["ovms"]
