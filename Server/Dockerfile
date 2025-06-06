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

# Copy and build Desktop.Win
COPY ["Desktop.Win/Desktop.Win.csproj", "Desktop.Win/"]
RUN dotnet restore "Desktop.Win/Desktop.Win.csproj"
COPY Desktop.Win/ ./Desktop.Win/
RUN dotnet publish "Desktop.Win/Desktop.Win.csproj" -c $ASPNETCORE_ENVIRONMENT -o /app/DesktopWinPublish /p:UseAppHost=false

# Copy the Windows client binary into the Server's wwwroot
RUN mkdir -p /app/publish/wwwroot/Content/Win-x64 && \
    cp /app/DesktopWinPublish/Remotely_Desktop.exe /app/publish/wwwroot/Content/Win-x64/

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Remotely_Server.dll"]

HEALTHCHECK \
  CMD curl -f http://localhost:${ASPNETCORE_HTTP_PORTS}/api/healthcheck || exit 1