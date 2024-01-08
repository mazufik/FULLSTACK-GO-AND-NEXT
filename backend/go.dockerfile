FROM golang:1.21.3-alpine

WORKDIR /app

COPY . .

# Download and install the depedencies:
RUN go get -d -v ./...

# Build the go app
RUN go build -o api .

EXPOSE 8000

CMD [ "./api" ]