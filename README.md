# Core contracts for TGS

## How to use (for Developement)

> Initialize TGS Platform

```bash
flow transactions send ./transactions/platform/initialize.cdc --signer=default
```

> Publish a TGS Platform controller

```bash
flow transactions send ./transactions/platform/publish-controller.cdc 0xAddress --signer=default
```

> Claim a TGS Platform controller

```bash
flow transactions send ./transactions/platform/claim-controller.cdc --signer=ControlerAccount
```

> Create a new TGS User

```bash
flow transactions send ./transactions/user/initialize.cdc user01 fb62bbf229fb28f7d903334e99282699b06686b3bb6dab87fae3cef92acb17f43f576b332a2ee91c36f2b117d4264ba96c65eceac22bb92ab5a6aad24e94d7c0 10.0 --signer=default
```

> Create a new TGS Application

```bash
flow transactions send ./transactions/application/initialize.cdc test fb62bbf229fb28f7d903334e99282699b06686b3bb6dab87fae3cef92acb17f43f576b332a2ee91c36f2b117d4264ba96c65eceac22bb92ab5a6aad24e94d7c0 10.0 --signer=default
```

> Register property service to an Application

```bash
flow transactions send ./transactions/application/blueprints/register-properties-service.cdc test --signer=default
```

> Generate a new anonymous user profile of property service in an Application

```bash
flow transactions send ./transactions/application/blueprints/generate-properties-profile.cdc test google anonymous01 --signer=default
```

> Set User property by property service in an Application

```bash
flow transactions send ./transactions/application/blueprints/set-user-property.cdc test google anonymous01 name "John Doe" nil --signer=default
```

> Take the profile of property service from the Application

```bash
flow transactions send ./transactions/application/blueprints/take-properties-profile.cdc test google anonymous01 user01 --signer=default
```

After taked profile, your can try set property again

```bash
flow transactions send ./transactions/application/blueprints/set-user-property.cdc test google anonymous01 gender "Man" nil --signer=default

flow transactions send ./transactions/application/blueprints/set-user-property.cdc test tgs user01 age 20 nil --signer=default
```

> Get User Info

```bash
flow scripts execute ./scripts/user/get-user-info.cdc tgs user01
```

> Get User property by property service in an Application

```bash
flow scripts execute ./scripts/application/blueprints/get-user-properties.cdc test google anonymous01 "[\"name\",\"gender\",\"age\"]" nil

flow scripts execute ./scripts/application/blueprints/get-user-properties.cdc test tgs user01 "[\"name\",\"gender\",\"age\"]" nil
```
