import subprocess
import concurrent.futures
import ipaddress
import os
import gzip
import shutil

# Load resolvers and subnets from text files
with open('resolvers.txt', 'r') as file:
    RESOLVERS = [line.strip() for line in file.readlines()]

with open('sub1.txt', 'r') as file:
    SUBNETS = [line.strip() for line in file.readlines()]

# Load GitHub token from file
with open('.github_token', 'r') as file:
    GITHUB_TOKEN = file.read().strip()

THREAD_COUNT = 3000
CHUNK_SIZE_MB = 100


def scan_subnet(subnet, resolver):
    result_filename = f"{subnet.replace('/', '-')}_result.txt"
    
    # Scan
    print(f"Scanning subnet: {subnet} using resolver: {resolver}")
    cmd = f"prips {subnet} | hakrevdns -t 3000 -r {resolver} -d -P udp -p 53 > {result_filename}"
    subprocess.run(cmd, shell=True)
    
    # If the result file is empty, return early and delete it
    if os.path.getsize(result_filename) == 0:
        os.remove(result_filename)
        print(f"No results for subnet: {subnet}. Skipping...")
        return

    # Gzip if file size > 100MB
    file_size_mb = os.path.getsize(result_filename) / (1024 * 1024)
    if file_size_mb > CHUNK_SIZE_MB:
        with open(result_filename, 'rb') as f_in:
            with gzip.open(result_filename + '.gz', 'wb') as f_out:
                shutil.copyfileobj(f_in, f_out)
        os.remove(result_filename)
        result_filename += '.gz'

    # Push to GitHub
    commit_message = f"Add results for {subnet}"
    authenticated_url = f"https://[TOKEN_HIDDEN]:{GITHUB_TOKEN}@github.com/RepoRascal/Scan.git"
    github_cmd = f"""
    git pull {authenticated_url} &&
    git add {result_filename} &&
    git commit -m "{commit_message}" &&
    git push {authenticated_url}
    """
    subprocess.run(github_cmd, shell=True)
    
    # Remove local files to save space
    os.remove(result_filename)



def main():
    with concurrent.futures.ThreadPoolExecutor(max_workers=THREAD_COUNT) as executor:
        resolver_index = 0
        futures = []
        for subnet in SUBNETS:
            resolver = RESOLVERS[resolver_index]
            futures.append(executor.submit(scan_subnet, subnet, resolver))
            resolver_index = (resolver_index + 1) % len(RESOLVERS)

        for future in concurrent.futures.as_completed(futures):
            try:
                future.result()
            except Exception as e:
                print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
