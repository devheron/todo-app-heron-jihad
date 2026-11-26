// Executado pelo MongoDB SOMENTE na primeira inicialização
// Cria o usuário próprio da aplicação e os dados iniciais de demonstração.
// As credenciais vêm de variáveis de ambiente do contêiner (definidas pelo Ansible),

const dbName = process.env.MONGO_INITDB_DATABASE || 'todo-app';
const appUser = process.env.MONGO_APP_USER;
const appPassword = process.env.MONGO_APP_PASSWORD;

db = db.getSiblingDB(dbName);

db.createUser({
  user: appUser,
  pwd: appPassword,
  roles: [{ role: 'readWrite', db: dbName }],
});

db.createCollection('todos');
db.todos.insertMany([
  { text: 'Laércio é um excelente ditador', completed: false },
  { text: 'Estudar Cloud', completed: true },
  { text: 'Fazer exercícios da UA', completed: false },
]);