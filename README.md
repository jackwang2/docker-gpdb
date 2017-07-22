# docker-gpdb
Pivotal Greenplum database with data type extension for CRoaring bitmap operation

# Building the Docker Image
You will first need to download the Pivotal Greenplum Database 5.0.0-beta.4 installer (.zip) located at https://network.pivotal.io/products/pivotal-gpdb and place it inside the docker working directory.

cd [docker working directory]

docker build -t [tag] .

# Running the Docker Image
docker run -i -d -p 5432:5432 -p 2022:22 [tag]

# Container Accounts
root/pivotal

gpadmin/pivotal

# Using psql in the Container
su - gpadmin

psql
