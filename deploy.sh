#!/bin/bash
# Deploy the static pages to the web server. PDFs live in S3 and are never uploaded.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

host="winmetta.org"
remote_dir="winmetta.org/dhamma-library" # relative to the remote home directory
dest="${host}:~/${remote_dir}"

# -c compares content, and no -t, so git-checkout timestamps do not show as changes.
# -i lists what changed and why. -8 prints Burmese filenames instead of \#ooo escapes.
# No --delete: files already on the server are never removed.
opts=(-rlpc -i -8
	--exclude "*.sh"
	--exclude ".git*"
	--exclude "*.pdf"
	--exclude ".DS_Store")

# Copy the live site to ~/winmetta.org-dhamma-library-backup-<hash> on the server, where
# <hash> covers every file path and content under the live folder. If a backup with that
# hash exists, the site has not changed since then, so nothing is copied.
backup_remote() {
	ssh "${host}" bash -s -- "${remote_dir}" <<'REMOTE'
set -euo pipefail
src="$HOME/$1"
hash=$(cd "$src" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0r sha256sum | sha256sum | cut -c1-16)
backup="$HOME/winmetta.org-dhamma-library-backup-${hash}"
if [[ -e ${backup} ]]; then
	echo "Backup already exists: ${backup}"
else
	tmp=$(mktemp -d "${backup}.XXXXXX")
	cp -a "${src}/." "${tmp}/"
	mv "${tmp}" "${backup}"
	echo "Backup created: ${backup}"
fi
REMOTE
}

echo "Checking files to sync ..."
changes=$(rsync -n "${opts[@]}" ./ "${dest}")

if [[ -z ${changes} ]]; then
	echo "Nothing to deploy. Server already matches."
	exit 0
fi

echo "${changes}"
echo
read -rp "Back up the current remote site first? [Y/n] " backup_confirm
if [[ ! ${backup_confirm} =~ ^[nN](o)?$ ]]; then
	backup_remote
fi

echo
read -rp "Copy these files to the remote web server (overwrites existing files)? [y/n] " copy_confirm
if [[ ${copy_confirm} =~ ^[yY](es)?$ ]]; then
	rsync -v "${opts[@]}" ./ "${dest}"
	echo "Done."
else
	echo "Cancelled. Nothing was copied."
fi
