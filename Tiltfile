docker_build('budget-app-db', './db/')
k8s_yaml('db/postgres.yaml')
k8s_resource('postgres-db', port_forwards=5432)