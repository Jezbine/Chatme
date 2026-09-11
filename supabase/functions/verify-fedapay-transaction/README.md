# verify-fedapay-transaction

Déployer :
```
supabase functions deploy verify-fedapay-transaction --no-verify-jwt
supabase secrets set FEDA_API_KEY=pk_live_xxx FEDA_ENV=live
```
Vérifier : `supabase functions logs verify-fedapay-transaction`
