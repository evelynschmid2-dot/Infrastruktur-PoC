# Start from a minimal Linux base image
FROM python:3.12-slim

# Install Ansible + ssh + sshpass (so we can talk to remote hosts)
RUN apt-get update && apt-get install -y \
    openssh-client \
    sshpass \
    && pip install ansible \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /ansible

# Copy the entire ansible-poc folder into the container
COPY . /ansible

# Default command when container runs - just open a shell
CMD ["/bin/bash"]