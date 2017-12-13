const path = require("path");
const mime = require("mime-types");
const koa = require("koa");
const send = require("koa-send");
const route = require("koa-route");
const logger = require("koa-logger");
const { postgraphql } = require("postgraphql");

const app = new koa();

app.use(logger());

const MEDIA_DIR = "media";
const HASH_REGEX = /^[0-9a-f]{40}$/;

async function media(ctx, name) {
  const [hash, extension, ...rest] = name.toLowerCase().split(".");

  const type = mime.lookup(extension);

  if (rest.length || !hash.match(HASH_REGEX) || !type) {
    console.log(type, rest, hash.match(HASH_REGEX));
    ctx.body = "Invalid media";
    ctx.status = 400;
  } else {
    const filePath = path.join(MEDIA_DIR, hash[0], hash[1], hash.slice(2));
    await send(ctx, filePath);
    ctx.type = type;
  }
}

app.use(route.get("/media/:name", media));

app.use(
  postgraphql("postgres:///recipes", "public", {
    graphiql: true,
    jwtSecret: "recipes",
    jwtPgTypeIdentifier: "public.jwt_token"
  })
);

app.listen(5000);
