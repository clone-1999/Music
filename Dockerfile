FROM golang:1.26.1-bookworm AS builder

WORKDIR /build

# hadolint ignore=DL3015
RUN apt-get update && \
    apt-get install -y \
        git \
        gcc \
        unzip \
        curl \
        zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./
RUN go mod tidy

COPY install.sh ./
COPY . .

# Cloud Platform က တောင်းနေတဲ့ 'myapp' နာမည်နဲ့ ကိုက်အောင် binary အထွက်ကို myapp လို့ ပြောင်းပေးလိုက်ပါတယ်
RUN chmod +x install.sh && \
    ./install.sh -n --quiet --skip-summary && \
    CGO_ENABLED=1 go build -v -trimpath -ldflags="-w -s" -o myapp ./cmd/app/


FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y \
        ffmpeg \
        curl \
        unzip \
        zlib1g && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /etc/ssl/certs /etc/ssl/certs

# appuser ကို ကြိုဆောက်ထားမှ Deno သွင်းတဲ့အခါ appuser ရဲ့ home directory ထဲ ထည့်လို့ရမှာဖြစ်ပါတယ်
RUN useradd -r -m -u 10001 appuser && \
    mkdir -p /app && \
    chown -R appuser:appuser /app

# Deno ကို appuser ရဲ့ Home directory (/home/appuser/.deno) ထဲ ရောက်အောင် သတ်မှတ်ပေးပါတယ်
ENV DENO_INSTALL=/home/appuser/.deno
ENV PATH=$DENO_INSTALL/bin:$PATH

RUN curl -fL \
      https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux \
      -o /usr/local/bin/yt-dlp && \
    chmod 0755 /usr/local/bin/yt-dlp && \
    curl -fsSL https://deno.land/install.sh -o /tmp/deno-install.sh && \
    sh /tmp/deno-install.sh && \
    rm -f /tmp/deno-install.sh && \
    chown -R appuser:appuser /home/appuser/.deno

WORKDIR /app

# Binary နာမည်ကို myapp အဖြစ်ပြောင်းလဲ ကူးယူပြီး permission ပေးပါတယ်
COPY --from=builder /build/myapp /app/myapp
RUN chown appuser:appuser /app/myapp

USER appuser

# Entrypoint ကိုလည်း Cloud က ခေါ်မယ့် လမ်းကြောင်းအတိုင်း ပြောင်းပေးလိုက်ပါတယ်
ENTRYPOINT ["/app/myapp"]
