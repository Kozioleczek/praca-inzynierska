const express = require("express");
const bodyParser = require("body-parser");
const { exec } = require("child_process");
const path = require("path");
const { v4: uuidv4 } = require("uuid");
const fs = require("fs");

const app = express();
app.use(bodyParser.json());

const ISO_DIR = path.join(__dirname, "isos");

// Ensure the directory for ISOs exists
if (!fs.existsSync(ISO_DIR)) {
  fs.mkdirSync(ISO_DIR);
}

// Serwowanie statycznych plików z folderu isos
app.use("/isos", express.static(ISO_DIR));

app.post("/api/generate-iso", (req, res) => {
  const {
    packages,
    isoUrl = "http://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso",
  } = req.body;

  if (!packages || packages.length === 0) {
    return res.status(400).send("No packages provided");
  }

  const isoName = `custom_ubuntu_${uuidv4()}.iso`;
  const packageList = packages.join(" ");

  // wysyłka response z informacja o nazwie pliku
  res.status(200).send({ isoName });

  // Generowanie ISO w tle
  const command = `./create_iso.sh ${isoName} "${packageList}" "${isoUrl}"`;
  console.log(`Executing command: ${command}`);

  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error creating ISO: ${error.message}`);
      console.error(stderr);
      return;
    }
    console.log(`ISO created: ${isoName}`);
    console.log(stdout);
  });
});

app.get("/api/download/:isoName", (req, res) => {
  const isoName = req.params.isoName;
  const filePath = path.join(ISO_DIR, isoName);

  fs.access(filePath, fs.constants.F_OK, (err) => {
    if (err) {
      console.error(`File not found: ${filePath}`);
      return res.status(404).send("File not found");
    }

    const downloadUrl = `${req.protocol}://${req.get("host")}/isos/${isoName}`;

    res.status(200).send({ downloadUrl: downloadUrl });
  });
});

app.get("/api/progress/:isoName", (req, res) => {
  const isoName = req.params.isoName;
  const logFilePath = path.join(ISO_DIR, `${isoName}.log`);

  fs.access(logFilePath, fs.constants.F_OK, (err) => {
    if (err) {
      console.error(`Log file not found: ${logFilePath}`);
      return res.status(404).send("Log file not found");
    }

    fs.readFile(logFilePath, "utf8", (err, data) => {
      if (err) {
        console.error(`Error reading log file: ${err.message}`);
        return res.status(500).send("Error reading log file");
      }

      const lines = data.trim().split("\n");
      const lastLine = lines[lines.length - 1];
      const progressMatch = lastLine.match(/(\d+)%/);
      const statusMatch = lastLine.split(":").slice(1).join(":").trim();

      if (progressMatch) {
        res.status(200).send({
          progress: parseInt(progressMatch[1], 10),
          status: statusMatch,
        });
      } else {
        res.status(200).send({
          progress: 0,
          status: "Unknown",
        });
      }
    });
  });
});

app.get("/api/logs", (req, res) => {
  const logDirPath = ISO_DIR;

  fs.readdir(logDirPath, (err, files) => {
    if (err) {
      console.error(`Error reading directory: ${err.message}`);
      return res.status(500).send("Error reading directory");
    }

    const logFiles = files.filter((file) => file.endsWith(".log"));
    const logsData = [];

    logFiles.forEach((file) => {
      const logFilePath = path.join(logDirPath, file);

      const data = fs.readFileSync(logFilePath, "utf8");

      const lines = data.trim().split("\n");
      const lastLine = lines[lines.length - 1];
      const progressMatch = lastLine.match(/(\d+)%/);
      const statusMatch = lastLine.split(":").slice(1).join(":").trim();

      const isoFileName = file.replace(".log", "");

      const downloadUrl = `${req.protocol}://${req.get(
        "host"
      )}/isos/${isoFileName}`;

      logsData.push({
        fileName: isoFileName,
        progress: progressMatch ? parseInt(progressMatch[1], 10) : 0,
        status: statusMatch || "Unknown",
        downloadUrl:
          parseInt(progressMatch[1], 10) === 100 ? downloadUrl : null,
      });
    });

    res.status(200).send(logsData);
  });
});

app.get("/", (req, res) => {
  res.redirect("/app");
});

// Serwowanie statycznych plików Vue z folderu 'dist'
app.use("/app", express.static(path.join(__dirname, "dist")));

// Obsługa routingu Vue
app.get("/app/*", (req, res) => {
  res.sendFile(path.join(__dirname, "dist", "index.html"));
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
