FROM node

WORKDIR /app/
ADD app.js /app/
ADD package* /app/

RUN npm install
CMD ["app.js"]
VOLUME /app
