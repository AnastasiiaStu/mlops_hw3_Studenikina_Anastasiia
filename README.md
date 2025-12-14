# ML Service Deployment with Blue-Green Strategy

## Структура проекта

```
ml-deployment-project/
├── app/
│   ├── main.py
│   ├── model.pkl
│   └── requirements.txt
├── .github/
│   └── workflows/
│       └── deploy.yml
├── nginx/
│   ├── nginx.blue.conf
│   └── nginx.green.conf
├── Dockerfile
├── docker-compose.blue.yml
├── docker-compose.green.yml
└── README.md
```

## Быстрый старт

```bash
# Соберите Docker-образ
docker build -t ml-service:v1.0.0 .

# Запустите Blue окружение
docker-compose -f docker-compose.blue.yml up -d

# Проверьте работу сервиса
curl http://localhost/health
curl -X POST http://localhost/predict -H "Content-Type: application/json" -d '{"features": [1, 2, 3, 4]}'
```

###  1: Подготовка окружения

```bash
git clone https://github.com/YOUR_USERNAME/ml-deployment-project.git
cd ml-deployment-project

docker --version
docker-compose --version
```

###  2: Локальное тестирование

#### Запуск Blue версии (v1.0.0)

```bash
docker build -t ml-service:v1.0.0 .
docker-compose -f docker-compose.blue.yml up -d

curl http://localhost/health
# Ожидаемый ответ: {"status":"ok","version":"v1.0.0"}

curl -X POST http://localhost/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
# Ожидаемый ответ: {"prediction":0,"model_version":"v1.0.0"}
```

#### Запуск Green версии (v1.1.0)

```bash
docker build -t ml-service:v1.1.0 --build-arg MODEL_VERSION=v1.1.0 .
docker-compose -f docker-compose.blue.yml down
docker-compose -f docker-compose.green.yml up -d

curl http://localhost/health
# Ожидаемый ответ: {"status":"ok","version":"v1.1.0"}
```

### 3: Переключение между версиями

```bash
# Если Green версия работает нормально
docker-compose -f docker-compose.green.yml up -d

# Откат на Blue при необходимости
docker-compose -f docker-compose.green.yml down
docker-compose -f docker-compose.blue.yml up -d

curl http://localhost/health
```

### 4: Настройка CI/CD на GitHub

 репозиторий на GitHub
```bash
git init
git add .
git commit -m "Initial commit: ML service with Blue-Green deployment"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/ml-deployment-project.git
git push -u origin main
```

2. секреты в GitHub
   - Settings → Secrets and variables → Actions
   - Добавьте CLOUD_TOKEN (опционально)

3. Workflow запустится автоматически при push в main

###  5: Проверка метрик и логов

```bash
# Логи Blue версии
docker-compose -f docker-compose.blue.yml logs -f ml-service

# Логи Green версии
docker-compose -f docker-compose.green.yml logs -f ml-service

# Статус контейнеров
docker ps

# Использование ресурсов
docker stats
```

## API Endpoints

### GET /health
Возвращает статус сервиса и версию модели.

Запрос:
```bash
curl http://localhost/health
```

Ответ:
```json
{
  "status": "ok",
  "version": "v1.0.0"
}
```

### POST /predict
Выполняет предсказание на основе входных данных.

Запрос:
```bash
curl -X POST http://localhost/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

Ответ:
```json
{
  "prediction": 0,
  "model_version": "v1.0.0"
}
```

## Тестирование стратегии Blue-Green

###  1: Успешное развертывание

```bash
# Запустите Blue (v1.0.0)
docker-compose -f docker-compose.blue.yml up -d
curl http://localhost/health

# Соберите и запустите Green (v1.1.0)
docker build -t ml-service:v1.1.0 --build-arg MODEL_VERSION=v1.1.0 .
docker-compose -f docker-compose.blue.yml down
docker-compose -f docker-compose.green.yml up -d
curl http://localhost/health
```

###  2: Rollback при ошибках

```bash
# Откат на Blue при проблемах с Green
docker-compose -f docker-compose.green.yml down
docker-compose -f docker-compose.blue.yml up -d
curl http://localhost/health
```
