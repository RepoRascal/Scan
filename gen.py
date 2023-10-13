def generate_ipv4_subnets(filename="subnets.txt"):
    with open(filename, "w") as file:
        for i in range(256):
            for j in range(256):
                for k in range(256):
                    subnet = f"{i}.{j}.{k}.0/24"
                    file.write(subnet + "\n")

if __name__ == "__main__":
    generate_ipv4_subnets()
