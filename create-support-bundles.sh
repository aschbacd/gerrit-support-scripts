#!/usr/bin/env bash

# all of these stem from https://www.shellcheck.net/wiki/
set -o pipefail  # propagate errors
set -u  # exit on undefined
set -e  # exit on non-zero return value
set -f  # disable globbing/filename expansion

# folders to back up
gerrit_support_bundle_dirs=(
	"/var/mnt"
	"/var/gerrit/etc"
	"/var/gerrit/logs"
)

# javamelody graphs to include
gerrit_graphs=(
	"usedMemory"
	"cpu"
	"activeThreads"
	"activeConnections"
	"httpHitsRate"
	"httpMeanTimes"
	"sqlHitsRate"
	"sqlMeanTimes"
	"gc"
	"fileDescriptors"
)

# check if dependencies are installed
dependencies=(
	"kubectl"
	"fzf"
)

for dependency in "${dependencies[@]}"; do
	if ! command -v "$dependency" &> /dev/null; then
		echo "The utility $dependency is required to run this script. Make sure to install it first."
		exit 1
	fi
done

cat << EOF

SUPPORT-BUNDLE-GENERATOR

Make sure to do the following steps first:

1. visit Gerrit via the browser
2. log in via sso
3. copy the cookie "GerritAccount"

EOF

# kubernetes clusters
kubernetes_clusters=$(kubectl config get-contexts --no-headers -o name)
user_kubernetes_clusters=()
while IFS='' read -r line; do
    user_kubernetes_clusters+=("${line}");
done < <(printf '%s\n' "${kubernetes_clusters[@]}" | fzf --header "Choose which clusters should be included." -m --bind shift-tab:toggle-all,tab:toggle)
echo "Kubernetes clusters: ${user_kubernetes_clusters[*]}"

# kubernetes namespace
default_kubernetes_namespace="gerrit"
read -rp "Kubernetes namespace [$default_kubernetes_namespace]: " user_kubernetes_namespace
gerrit_namespace=${user_kubernetes_namespace:-$default_kubernetes_namespace}

# output dir
default_output_dir="/tmp/gerrit_$(date '+%Y-%m-%d_%H-%M')"
read -rp "Output location [$default_output_dir]: " user_output_dir
gerrit_dir=${user_output_dir:-$default_output_dir}

# gerrit account cookie
read -rp "GerritAccount cookie: " gerrit_cookie
if [ -z "$gerrit_cookie" ]; then
	echo "Invalid cookie!"
	exit 1
fi

# create output dir
rm -rf "$gerrit_dir"
mkdir "$gerrit_dir"

# create support bundle in every cluster
for cluster in "${user_kubernetes_clusters[@]}"; do
	echo -e "\nCluster: $cluster\n"
	kubectl config use-context "$cluster"
	output_dir="$gerrit_dir/$cluster"

	# create support bundle for every pod
	for pod in $(kubectl get pod -n "$gerrit_namespace" -l app=gerrit --no-headers -o custom-columns=":metadata.name"); do
		# create support bundle
		echo -e "\nCreating support bundle for $pod ...\n"
		# shellcheck disable=SC2016
		kubectl exec -n "$gerrit_namespace" "$pod" -c gerrit -- bash -c \
		"rm -rf /tmp/gerrit.tar /tmp/gerrit.tar.gz /tmp/info /tmp/graphs /tmp/threadsDump &&
		echo 'Adding config and logs ...' &&
		for dir in ${gerrit_support_bundle_dirs[*]}; do
			tar --exclude='secure.config' --exclude='ssh_host_*_key' -rf /tmp/gerrit.tar "'"$dir"'" 2>/dev/null;
		done &&
		echo 'Getting system info ...' &&
		mkdir /tmp/info /tmp/graphs /tmp/threadsDump &&
		cat /proc/cpuinfo /proc/meminfo > /tmp/info/cpu-memory.txt &&
		df -T /var/gerrit > /tmp/info/gerrit-site-disk-usage.txt &&
		ls -l /var/gerrit/plugins > /tmp/info/plugins.txt &&
		ls -l /var/gerrit/lib > /tmp/info/libraries.txt &&
		tar -C /tmp -rf /tmp/gerrit.tar info &&
		echo 'Getting javamelody graphs ...' &&
		for graph in ${gerrit_graphs[*]}; do
			curl -f -s -G http://localhost:8080/monitoring -d 'width=960' -d 'height=400' -d 'graph='"'"$graph"'" --cookie GerritAccount=""$gerrit_cookie"" -o /tmp/graphs/"'"$graph"'".png
		done &&
		tar -C /tmp -rf /tmp/gerrit.tar graphs &&
		echo 'Getting javamelody threads dump ...' &&
		curl -f -s 'http://localhost:8080/monitoring?part=threadsDump' --cookie GerritAccount=$gerrit_cookie -o /tmp/threadsDump/threadsDump.txt &&
		tar -C /tmp -rf /tmp/gerrit.tar threadsDump &&
		echo 'Zipping archive ...' &&
		gzip /tmp/gerrit.tar &&
		rm -rf /tmp/info /tmp/graphs /tmp/threadsDump"

		# get remote checksum
		sum_remote="$(kubectl exec -n "$gerrit_namespace" "$pod" -c gerrit -- bash -c 'sha256sum /tmp/gerrit.tar.gz' | awk '{ print $1 }')"

		# download support bundle
		echo "Downloading support bundle for $pod ..."
		kubectl cp --retries=10 -n "$gerrit_namespace" -c gerrit "$pod":/tmp/gerrit.tar.gz "$output_dir"/"$pod".tar.gz

		# get local checksum
		sum_local="$(sha256sum "$output_dir"/"$pod".tar.gz | awk '{ print $1 }')"

		# compare checksums
		if [ "$sum_local" = "$sum_remote" ]; then
			echo "Successfully saved support bundle for $pod"
		else
			echo "Error getting support bundle for $pod"
			exit 1
		fi
	done
done

echo -e "\nSupport bundles saved to $gerrit_dir\n"

# open output dir on macos
if command -v open &> /dev/null; then
	open "$gerrit_dir"
fi
