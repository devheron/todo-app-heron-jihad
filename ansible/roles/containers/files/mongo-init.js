// Executado pelo MongoDB SOMENTE na primeira inicialização (volume de dados vazio).
// Cria o usuário próprio da aplicação e os dados iniciais de demonstração.
// As credenciais vêm de variáveis de ambiente do contêiner (definidas pelo Ansible),
// por isso nenhuma senha fica escrita neste arquivo.

const dbName = process.env.MONGO_INITDB_DATABASE || 'todo-app';
const appUser = process.env.MONGO_APP_USER;
const appPassword = process.env.MONGO_APP_PASSWORD;

db = db.getSiblingDB(dbName);

// Usuário da aplicação: acesso de leitura/escrita só ao banco da aplicação
db.createUser({
  user: appUser,
  pwd: appPassword,
  roles: [{ role: 'readWrite', db: dbName }],
});

// Dados iniciais de demonstração (os mesmos do init-mongo.js original do projeto)
db.createCollection('todos');
db.todos.insertMany([
  { text: 'Laércio é um excelente professor', completed: false },
  { text: 'Estudar Cloud', completed: true },
  { text: 'Fazer exercícios da UA', completed: false },
]);