# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY Server/Server.csproj ./
RUN dotnet restore Server.csproj
COPY Server/. ./
RUN dotnet publish Server.csproj -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0

EXPOSE ${ASPNETCORE_HTTP_PORTS}

RUN apt -y update && apt -y install curl
WORKDIR /app
COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "Remotely_Server.dll"]

HEALTHCHECK \
  CMD curl -f http://localhost:${ASPNETCORE_HTTP_PORTS}/api/healthcheck || exit 1