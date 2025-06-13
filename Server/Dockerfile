FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE ${ASPNETCORE_HTTP_PORTS}

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
RUN apt-get update && apt-get install -y nodejs npm curl zip && rm -rf /var/lib/apt/lists/*
ARG ASPNETCORE_ENVIRONMENT=Production
WORKDIR /src
COPY ["Server/Server.csproj", "Server/"]
RUN dotnet restore "Server/Server.csproj"
COPY . .
WORKDIR "/src/Server"
RUN dotnet build "Server.csproj" -c $ASPNETCORE_ENVIRONMENT -o /app/build

FROM build AS publish
ARG ASPNETCORE_ENVIRONMENT=Production
RUN dotnet publish "Server.csproj" -c $ASPNETCORE_ENVIRONMENT -o /app/publish /p:UseAppHost=false

# Build only Linux-compatible clients during Docker build
WORKDIR /src
RUN mkdir -p Server/wwwroot/Content && \
    # Build agents for Linux and Windows
    dotnet publish Agent/Agent.csproj -c Release -r win-x64 --self-contained -o Agent/bin/publish/win-x64 && \
    dotnet publish Agent/Agent.csproj -c Release -r linux-x64 --self-contained -o Agent/bin/publish/linux-x64 && \
    # Create agent ZIP files
    cd Agent/bin/publish/win-x64 && zip -r ../../../../Server/wwwroot/Content/Remotely-Win-x64.zip . && cd /src && \
    cd Agent/bin/publish/linux-x64 && zip -r ../../../../Server/wwwroot/Content/Remotely-Linux.zip . && cd /src && \
    # Build only Linux desktop client (Windows desktop requires Windows-specific frameworks)
    dotnet publish Desktop.Linux/Desktop.Linux.csproj -c Release -r linux-x64 --self-contained -o Server/wwwroot/Content/Linux-x64 && \
    # Create installation scripts
    echo '#!/bin/bash' > Server/wwwroot/Content/Install-Ubuntu-x64.sh && \
    echo 'curl -L https://remotely.redfox.lan/Content/Remotely-Linux.zip -o /tmp/remotely-agent.zip' >> Server/wwwroot/Content/Install-Ubuntu-x64.sh && \
    echo 'unzip /tmp/remotely-agent.zip -d /opt/remotely-agent' >> Server/wwwroot/Content/Install-Ubuntu-x64.sh && \
    echo 'chmod +x /opt/remotely-agent/Remotely_Agent' >> Server/wwwroot/Content/Install-Ubuntu-x64.sh && \
    chmod +x Server/wwwroot/Content/Install-Ubuntu-x64.sh

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
# Copy all client files built during Docker build
RUN mkdir -p /app/wwwroot/Content
COPY --from=publish /src/Server/wwwroot/Content/ /app/wwwroot/Content/
ENTRYPOINT ["dotnet", "Remotely_Server.dll"]

HEALTHCHECK \
  CMD curl -f http://localhost:${ASPNETCORE_HTTP_PORTS}/api/healthcheck || exit 1