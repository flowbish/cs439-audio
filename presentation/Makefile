
all: serve

serve: 
	npm install
	ssh -f -R \*:3000:localhost:3000 -N flowbish.me
	node server.js
