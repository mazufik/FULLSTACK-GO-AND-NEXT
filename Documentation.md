# Basic Fullstack CRUD Using Go, Next.JS, POstgreSQL, and Docker

## #1 Create Folder Project

Create new folder on your directory for the project, ex. `fullstack-go-crud`.

## #2 Create File `compose.yaml`

And than, create a new file on your project folder with file name `compose.yaml`. Add a script like the following:

```yaml
services:
  db:
    container_name: db
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    ports:
      - 5432:5432
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata: {}
```

To run the file `compose.yaml` in docker, type the following command in the terminal/cmd.

```bash
 docker compose up -d db
```

To check whether the database container is running or not, type the following command in the terminal.

```bash
 docker ps -a
```

or

```bash
 docker ps
```

And for check create database, we can check inside the database container with the command.

```bash
 docker exec -it db psql -U postgres
```

## #3 Create `backend`

We start creating a project by creating the backend first.

```bash
 mkdir backend
```

Came to inside `backend` folder and create go project initialize with command.

```bash
 go mod init golang-api
```

Install golang module for this project:

```bash
 go get github.com/gorilla/mux github.com/lib/pq 
```

Create file `main.go` and `go.dockerfile`. Open file `main.go` and add syntax like this.

- file `main.go`

```go
package main

import (
 "database/sql"
 "encoding/json"
 "log"
 "net/http"
 "os"

 "github.com/gorilla/mux"
 _ "github.com/lib/pq"
)

type User struct {
 Id    int    `json:"id"`
 Name  string `json:"name"`
 Email string `json:"email"`
}

// main function
func main() {
 // connect to database
 db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
 if err != nil {
  log.Fatal(err)
 }
 defer db.Close()

 // create table if not exist
 _, err = db.Exec("CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name TEXT, email TEXT)")
 if err != nil {
  log.Fatal(err)
 }

 // create router
 router := mux.NewRouter()
 router.HandleFunc("/api/go/users", getUsers(db)).Methods("GET")
 router.HandleFunc("/api/go/users", createUser(db)).Methods("POST")
 router.HandleFunc("/api/go/users/{id}", getUser(db)).Methods("GET")
 router.HandleFunc("/api/go/users/{id}", updateUser(db)).Methods("PUT")
 router.HandleFunc("/api/go/users/{id}", deleteUser(db)).Methods("DELETE")

 // wrap the router with CORS and JSON content type middlewares
 enhancedRouter := enableCORS(jsonContentTypeMiddleware(router))

 // start server
 log.Fatal(http.ListenAndServe(":8000", enhancedRouter))
}

func enableCORS(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  // Set CORS headers
  w.Header().Set("Access-Control-Allow-Origin", "*") // Allow any origin
  w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

  // check if the request is for CORS preflight
  if r.Method == "OPTIONS" {
   w.WriteHeader(http.StatusOK)
   return
  }

  // Pass down the request to the next middleware (or final handler)
  next.ServeHTTP(w, r)
 })
}

func jsonContentTypeMiddleware(next http.Handler) http.Handler {
 return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
  // set JSON Content-Type
  w.Header().Set("Content-Type", "application/json")
  next.ServeHTTP(w, r)
 })
}

// get all users
func getUsers(db *sql.DB) http.HandlerFunc {
 return func(w http.ResponseWriter, r *http.Request) {
  rows, err := db.Query("SELECT * FROM users")
  if err != nil {
   log.Fatal(err)
  }
  defer rows.Close()

  users := []User{} // array of users
  for rows.Next() {
   var u User
   if err := rows.Scan(&u.Id, &u.Name, &u.Email); err != nil {
    log.Fatal(err)
   }
   users = append(users, u)
  }
  if err := rows.Err(); err != nil {
   log.Fatal(err)
  }

  json.NewEncoder(w).Encode(users)
 }
}

// get user by id
func getUser(db *sql.DB) http.HandlerFunc {
 return func(w http.ResponseWriter, r *http.Request) {
  vars := mux.Vars(r)
  id := vars["id"]

  var u User
  err := db.QueryRow("SELECT * FROM users WHERE id = $1", id).Scan(&u.Id, &u.Name, *&u.Email)
  if err != nil {
   w.WriteHeader(http.StatusNotFound)
   return
  }

  json.NewEncoder(w).Encode(u)
 }
}

// create user
func createUser(db *sql.DB) http.HandlerFunc {
 return func(w http.ResponseWriter, r *http.Request) {
  var u User
  json.NewDecoder(r.Body).Decode(&u)

  err := db.QueryRow("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id", u.Name, u.Email).Scan(&u.Id)
  if err != nil {
   log.Fatal(err)
  }

  json.NewEncoder(w).Encode(u)
 }
}

// update user
func updateUser(db *sql.DB) http.HandlerFunc {
 return func(w http.ResponseWriter, r *http.Request) {
  var u User
  json.NewDecoder(r.Body).Decode(&u)

  vars := mux.Vars(r)
  id := vars["id"]

  // Execute the update query
  _, err := db.Exec("UPDATE users SET name = $1, email = $2 WHERE id = $3", u.Name, u.Email, id)
  if err != nil {
   log.Fatal(err)
  }

  // Retrieve the updated user data from the database
  var updatedUser User
  err = db.QueryRow("SELECT id, name, email FROM users WHERE id = $1", id).Scan(&updatedUser.Id, &updatedUser.Name, &updatedUser.Email)
  if err != nil {
   log.Fatal(err)
  }

  // Send the updated user data in the response
  json.NewEncoder(w).Encode(updatedUser)
 }
}

// delete user
func deleteUser(db *sql.DB) http.HandlerFunc {
 return func(w http.ResponseWriter, r *http.Request) {
  vars := mux.Vars(r)
  id := vars["id"]

  var u User
  err := db.QueryRow("SELECT * FROM users WHERE id = $1", id).Scan(&u.Id, &u.Name, &u.Email)
  if err != nil {
   w.WriteHeader(http.StatusNotFound)
   return
  } else {
   _, err := db.Exec("DELETE FROM users WHERE id = $1", id)
   if err != nil {
    // todo : fix error handling
    w.WriteHeader(http.StatusNotFound)
    return
   }

   json.NewEncoder(w).Encode("User deleted")
  }
 }
}
```

Open file `go.dockerfile` and add syntax like this.

- file `go.dockerfile`

```yaml
FROM golang:1.21.3-alpine

WORKDIR /app

COPY . .

# Download and install the depedencies:
RUN go get -d -v ./...

# Build the go app
RUN go build -o api .

EXPOSE 8000

CMD [ "./api" ]
```

Now, open again file `compose.yaml` on root folder project, add this syntax.

- file `compose.yaml`

```yaml
services:
  goapp:
    container_name: goapp
    image: goapp:1.0.0
    build:
      context: ./backend
      dockerfile: go.dockerfile
    environment:
      DATABASE_URL: 'postgres://postgres:postgres@db:5432/postgres?sslmode=disable'
    ports:
      - '8000:8000'
    depends_on:
      - db

  db:
    container_name: db
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    ports:
      - 5432:5432
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata: {}
```

For try this applications, we can following this command on terminal/cmd.

```bash
 docker compose build
```

```bash
 docker compose up -d goapp
```

## #4 Create 'frontend'

Now, we will create frontend project using Next.js, Open the command/cmd and following command at bellow.

```bash
 npx create-next-app@latets --no-git
```

move the directory to frontend project. Than install axios.

```bash
 cd frontend

 npm i axios
```

for try tu run project frontend type on command/cmd `npm run dev` and open the browser and type `http://localhost:3000`.

And than open the project using your editor favorite, this project i use text editor vscode.

Create folder `components` on folder `src`, add file `CardComponent.tsx` and `UserInterface.tsx` to folder `components`.

- file `CardComponent.tsx`

```typescript
import React from 'react';

interface Card {
    id: number;
    name: string;
    email: string;
}

const CardComponent: React.FC<{ card: Card }> = ({ card }) => {
    return (
        <div className='bg-white shadow-lg rounded-lg p-2 mb-2 hover:bg-gray-100'>
            <div className='text-sm text-gray-600'>Id: {card.id}</div>
            <div className='text-lg font-semibold text-gray-800'>{card.name}</div>
            <div className='text-md text-gray-700'>{card.email}</div>
        </div>
    );
}

export default CardComponent;
```

- file `UserInterface.tsx`

```typescript
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import CardComponent from './CardComponent';
import Image from 'next/image';

interface User {
    id: number;
    name: string;
    email: string;
}

interface UserInterfaceProps {
    backendName: string; //go
}

const UserInterface: React.FC<UserInterfaceProps> = ({ backendName }) => {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
    const [users, setUsers] = useState<User[]>([]);
    const [newUser, setNewUser] = useState({ name: '', email: '' });
    const [updateUser, setUpdateUser] = useState({ id: '', name: '', email: '' });

    // Define styles based on the backend name
    const backgroundColors: { [key: string]: string } = {
        go: 'bg-cyan-500',
    };

    const buttonColors: { [key: string]: string } = {
        go: 'bg-cyan-700 hover:bg-blue-600',
    };

    const bgColor = backgroundColors[backendName as keyof typeof backgroundColors] || 'bg-gray-200';
    const btnColor = buttonColors[backendName as keyof typeof buttonColors] || 'bg-gray-500 hover:bg-gray-600';

    // Fetch all users
    useEffect(() => {
        const fetchData = async () => {
            try {
                const response = await axios.get(`${apiUrl}/api/${backendName}/users`);
                setUsers(response.data.reverse());
            } catch (error) {
                console.error('Error fetching data:', error);
            }
        };

        fetchData();
    }, [backendName, apiUrl]);

    // Create a new user
    const createUser = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();

        try {
            const response = await axios.post(`${apiUrl}/api/${backendName}/users`, newUser);
            setUsers([response.data, ...users]);
            setNewUser({ name: '', email: '' });
        } catch (error) {
            console.error('Error creating user:', error);
        }
    };

    // Update a user
    const handleUpdateUser = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        try {
            await axios.put(`${apiUrl}/api/${backendName}/users/${updateUser.id}`, { name: updateUser.name, email: updateUser.email });
            setUpdateUser({ id: '', name: '', email: '' });
            setUsers(
                users.map((user) => {
                    if (user.id === parseInt(updateUser.id)) {
                        return { ...user, name: updateUser.name, email: updateUser.email };
                    }
                    return user;
                })
            );
        } catch (error) {
            console.error('Error updating user:', error);
        }
    };

    // Delete a user
    const deleteUser = async (userId: number) => {
        try {
            await axios.delete(`${apiUrl}/api/${backendName}/users/${userId}`);
            setUsers(users.filter((user) => user.id !== userId));
        } catch (error) {
            console.error('Error deleting user:', error);
        }
    }

    return (
        <div className={`user-interface ${bgColor} ${backendName} w-full max-w-md p-4 my-4 rounded shadow`}>
            <Image
                src="/next.svg"
                className="w-20 h-20 mb-6 mx-auto"
                width={20}
                height={20}
                alt="Logo"
            />
            <h2 className="text-xl font-bold text-center text-white mb-6">List Contact</h2>

            {/* Create user */}
            <form onSubmit={createUser} className="mb-6 p-4 bg-blue-100 rounded shadow">
                <input
                    placeholder="Name"
                    value={newUser.name}
                    onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
                    className="mb-2 w-full p-2 border border-gray-300 rounded"
                />
                <input
                    placeholder="Email"
                    value={newUser.email}
                    onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                    className="mb-2 w-full p-2 border border-gray-300 rounded"
                />
                <button type="submit" className="w-full p-2 text-white bg-blue-500 rounded hover:bg-blue-600">
                    Add User
                </button>
            </form>

            {/* Update user */}
            <form onSubmit={handleUpdateUser} className="mb-6 p-4 bg-blue-100 rounded shadow">
                <input
                    placeholder="User Id"
                    value={updateUser.id}
                    onChange={(e) => setUpdateUser({ ...updateUser, id: e.target.value })}
                    className="mb-2 w-full p-2 border border-gray-300 rounded"
                />
                <input
                    placeholder="New Name"
                    value={updateUser.name}
                    onChange={(e) => setUpdateUser({ ...updateUser, name: e.target.value })}
                    className="mb-2 w-full p-2 border border-gray-300 rounded"
                />
                <input
                    placeholder="New Email"
                    value={updateUser.email}
                    onChange={(e) => setUpdateUser({ ...updateUser, email: e.target.value })}
                    className="mb-2 w-full p-2 border border-gray-300 rounded"
                />
                <button type="submit" className="w-full p-2 text-white bg-green-500 rounded hover:bg-green-600">
                    Update User
                </button>
            </form>

            {/* display users */}
            <div className="space-y-4">
                {users.map((user) => (
                    <div key={user.id} className="flex items-center justify-between bg-white p-4 rounded-lg shadow">
                        <CardComponent card={user} />
                        <button onClick={() => deleteUser(user.id)} className={`${btnColor} text-white py-2 px-4 rounded`}>
                            Delete User
                        </button>
                    </div>
                ))}
            </div>
        </div>
    );
};

export default UserInterface;
```

Open file `index.tsx` on folder `/src/pages` and following syntax at bellow:

- file `index.tsx`

```typescript
import React from 'react';
import UserInterface from '@/components/UserInterface';

const Home: React.FC = () => {
  return (
    <main className='flex flex-wrap justify-center items-start min-h-screen bg-gray-100'>
      <div className='m-4'>
        <UserInterface backendName='go' />
      </div>
    </main>
  );
}

export default Home;
```

Create file `.dockerignore` and `next.dockerfile` on folder `frontend`.

- file `.dockerignore`

```yaml
**/node_modules
```

- file `next.dockerfile`

```yaml
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
    if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
    else echo "Lockfile not found." && exit 1; \
    fi


# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# If using npm comment out above and use below instead
# RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
# set hostname to localhost
ENV HOSTNAME "0.0.0.0"

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/next-config-js/output
CMD ["node", "server.js"]
```

Open again file `compose.yaml`, and add this syntax.

- file `compose.yaml`

```yaml
services:
  nextapp:
    container_name: nextapp
    image: nextapp:1.0.0
    build:
      context: ./frontend
      dockerfile: next.dockerfile
    ports:
      - '3000:3000'
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000
    depends_on:
      - goapp
  goapp:
    container_name: goapp
    image: goapp:1.0.0
    build:
      context: ./backend
      dockerfile: go.dockerfile
    environment:
      DATABASE_URL: 'postgres://postgres:postgres@db:5432/postgres?sslmode=disable'
    ports:
      - '8000:8000'
    depends_on:
      - db

  db:
    container_name: db
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    ports:
      - 5432:5432
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata: {}
```

- file `next.config.js`

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone'
}

module.exports = nextConfig
```
