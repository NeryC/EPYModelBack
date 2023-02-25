FROM node:18

RUN mkdir -p /user/src/app

WORKDIR /user/src/app

RUN apt-get update && \
    apt-get remove -y python && \
    apt-get install -y python3 r-base python3-pip zip unzip vim locales locales-all

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

RUN pip install --upgrade pip

RUN pip install robotframework robotframework-seleniumlibrary

RUN pip install selenium ipython webdriver-manager pandas

# Install chromedriver
RUN wget -N https://chromedriver.storage.googleapis.com/111.0.5563.19/chromedriver_linux64.zip -P ~/
RUN unzip ~/chromedriver_linux64.zip -d ~/
RUN rm ~/chromedriver_linux64.zip
RUN mv -f ~/chromedriver /usr/local/bin/chromedriver
RUN chown root:root /usr/local/bin/chromedriver
RUN chmod 0755 /usr/local/bin/chromedriver

# Install chrome broswer
RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list
RUN apt-get -y update
RUN apt-get -y install google-chrome-stable

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3000

CMD [ "npm", "start" ]