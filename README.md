# 🔑 Kawan Keys

Painel web para **criar, renovar, revogar e apagar keys**, com API de validação para o script Lua.

## Rodar no seu PC (teste)
Precisa do Node 18+.

```bash
ADMIN_PASSWORD=suasenha node server.js      # Linux/Mac
set ADMIN_PASSWORD=suasenha && node server.js   # Windows (cmd)
```
Abra http://localhost:3000 e entre com a senha.

## Colocar online (para o script conseguir acessar)
Qualquer host que rode Node serve (Render, Railway, Fly.io, VPS…).

Variáveis de ambiente:
- `ADMIN_PASSWORD`  → senha do painel (obrigatória, use uma forte)
- `DATA_DIR`        → pasta onde fica o `keys.json` (aponte para um **disco persistente**, senão as keys somem quando o host reinicia)
- `SESSION_SECRET`  → opcional, texto aleatório longo

Comando de start: `node server.js` (sem `npm install`, não há dependências).
Use sempre HTTPS (os hosts acima já dão).

## API de validação (usada pelo Lua)
`GET /api/validate?key=KW-XXXX-XXXX-XXXX&hwid=ID_DO_PC`

Respostas:
```json
{"valid":true,"admin":false,"expiresAt":1795776447,"now":1795171647}
{"valid":false,"reason":"not_found | revoked | expired | hwid_mismatch | hwid_required"}
```

## No script
Abra `Kawan_Menu_com_Servidor_de_Keys.lua` e troque `SERVER_URL` pela URL do seu painel.
A key mestra `1602` e a key `MEMBRO` que estavam dentro do script foram removidas — crie as suas no painel
(marque “Key ADMIN” para as que liberam a área do Dono).

## Funções do painel
- Gerar 1 a 100 keys de uma vez (1/7/30/90 dias, 1 ano, personalizado ou vitalícia), prefixo e observação
- Renovar (somar ao tempo atual ou redefinir), revogar/restaurar, apagar, editar observação
- Travar a key no 1º dispositivo (HWID) e resetar o HWID
- Busca, filtro por status, contadores, copiar todas as ativas
