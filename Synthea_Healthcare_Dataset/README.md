# Synthea dataset (not in git)

The CSVs are too large for GitHub (`observations.csv` is 170 MB, and GitHub rejects
files over 100 MB), so they are shared outside the repo. Get the dataset zip from the
team and extract the CSVs directly into this folder.

The pipeline loads these five files (see `sql/schema/01_staging_and_load.sql`):

- `patients.csv`
- `encounters.csv`
- `conditions.csv`
- `medications.csv`
- `observations.csv`

`docker-compose.yml` mounts this folder into the SQL Server container at `/data`.
