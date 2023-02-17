FROM node:18

RUN mkdir -p /user/src/app

WORKDIR /user/src/app

RUN apt-get update && \
    apt-get remove -y python && \
    apt-get install -y python3 r-base python3-pip

# RUN wget "https://download.mozilla.org/?product=firefox-latest&os=linux&lang=pt-BR" -O firefox.tar.bz2
# RUN tar -jxvf  firefox.tar.bz2 -C /usr/local/bin/

# curl -L https://github.com/mozilla/geckodriver/releases/download/v0.30.0/geckodriver-v0.30.0-linux64.tar.gz | tar xz -C /usr/local/bin

RUN pip install robotframework robotframework-seleniumlibrary


COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD [ "npm", "start" ]