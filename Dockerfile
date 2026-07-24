# Stage build: Debian Bookworm (glibc) agar CGO + libwebp (chai2010/webp) bisa dikompilasi.
# Alpine/musl sering gagal saat link paket webp berbasis CGO.
FROM golang:1.25-bookworm AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    libjpeg62-turbo-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copiar apenas arquivos de dependências primeiro para cachear o download
COPY go.mod go.sum ./

# whatsmeow agora vem do proxy oficial (go.mau.fi/whatsmeow, sem replace local) —
# não há mais submódulo whatsmeow-lib para copiar.
RUN go mod download

# Copiar o restante do código
COPY . .

ARG VERSION=dev
# Keterangan: compile binary server dengan CGO (dibutuhkan chai2010/webp) dan injeksi versi.
RUN CGO_ENABLED=1 go build -ldflags "-X main.version=${VERSION}" -o server ./cmd/evolution-go

# Stage final: bookworm-slim agar runtime cocok dengan binary yang di-link ke glibc/libwebp.
FROM debian:bookworm-slim AS final

# poppler-utils provides pdftoppm, used to rasterize PDF page 1 for /send/media document thumbnails
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    ffmpeg \
    libjpeg62-turbo \
    libwebp7 \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /build/server .
COPY --from=build /build/manager/dist ./manager/dist
COPY --from=build /build/VERSION ./VERSION

ENV TZ=America/Sao_Paulo

ENTRYPOINT ["/app/server"]
