import time
from pathlib import Path

from common import connect, initialize_database, now_epoch


def sweep() -> int:
    now = now_epoch()
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT id, incoming_path, normalized_path
              FROM jobs
             WHERE expires_at <= ?
            """,
            (now,),
        ).fetchall()
        for row in rows:
            file_rows = connection.execute(
                "SELECT incoming_path FROM job_files WHERE job_id = ?",
                (row["id"],),
            ).fetchall()
            for value in (row["incoming_path"], row["normalized_path"]):
                if value:
                    Path(value).unlink(missing_ok=True)
            for file_row in file_rows:
                Path(file_row["incoming_path"]).unlink(missing_ok=True)
            # Deleting the row (and its cascading job_files rows) removes the
            # encrypted phone number and all job metadata at the 48-hour limit.
            connection.execute("DELETE FROM jobs WHERE id = ?", (row["id"],))
        return len(rows)


def main() -> None:
    initialize_database()
    sweep()
    while True:
        time.sleep(300)
        sweep()


if __name__ == "__main__":
    main()
