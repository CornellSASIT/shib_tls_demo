function generate_hs256_jwt(claims, key, valid) {
  var header = { typ: 'JWT', alg: 'HS256' };  Object.assign(claims, 
    {exp: Math.floor(Date.now()/1000) + valid}
  );  var s = [header, claims]
    .map(JSON.stringify)
    .map((v) => v.toUTF8())
    .map((v) => v.toString('base64url'))
    .join('.');  var h = require('crypto').createHmac('sha256', key);  return s + '.' + h.update(s).digest().toString('base64url');
}function jwt(r) {
  var s = r.variables;
  var claims = {
    iss: r.variables.server_name,
    sub: r.variables.shib_remote_user,
    groups: r.variables.shib_remote_groups.split(";")
  };  var generatedJwt = generate_hs256_jwt(
    claims, "SECRET!!", 600
  );  return generatedJwt;
}export default {jwt};
