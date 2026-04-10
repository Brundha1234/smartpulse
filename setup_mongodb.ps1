# MongoDB Setup Script for Windows
echo "Setting up MongoDB for SmartPulse..."

# Download MongoDB Community Server
echo "Downloading MongoDB..."
Invoke-WebRequest -Uri "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.5-signed.msi" -OutFile "mongodb-installer.msi"

# Install MongoDB silently
echo "Installing MongoDB..."
Start-Process msiexec.exe -ArgumentList '/i mongodb-installer.msi /quiet /norestart' -Wait

# Add MongoDB to PATH
$mongoPath = "C:\Program Files\MongoDB\Server\7.0\bin"
[Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";" + $mongoPath, "Machine")

# Create MongoDB data directory
New-Item -ItemType Directory -Force -Path "C:\data\db"

# Start MongoDB service
echo "Starting MongoDB service..."
Start-Process mongod.exe -ArgumentList '--dbpath C:\data\db' -WindowStyle Hidden

echo "MongoDB setup complete!"
echo "MongoDB is running on mongodb://localhost:27017"
