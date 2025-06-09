FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
USER $APP_UID
WORKDIR /app
EXPOSE ${ASPNETCORE_HTTP_PORTS}

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
RUN apt-get update && apt-get install -y nodejs npm curl && rm -rf /var/lib/apt/lists/*
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

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
# Copy the Windows client binary from the repository
COPY wwwroot/Content/Win-x64/Remotely_Desktop.exe /app/wwwroot/Content/Win-x64/
ENTRYPOINT ["dotnet", "Remotely_Server.dll"]

HEALTHCHECK \
  CMD curl -f http://localhost:${ASPNETCORE_HTTP_PORTS}/api/healthcheck || exit 1