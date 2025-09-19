# Trust store generator

# Scripts

ca_trust_store_prep.sh

- Read all certs in a dir
- Convert them all to both PEM and DER formats
- Creates a Chef data bag item
- Adds them to a Java cacerts file

certs_to_databags.sh

- Only create a Chef data bag item

## Verify cacert updates

```
diff <(keytool -list -keystore ORIGINAL_CACERTS_FILE -storepass changeit) <(keytool -list -keystore UPDATED_CACERTS_FILE -storepass changeit)
```
