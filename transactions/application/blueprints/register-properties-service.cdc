import "TGSLogging"
import "TGSEntity"
import "TGSPlatform"
import "PropertyService"

transaction(name: String) {
    let tgsPub: &TGSPlatform.Entity{TGSPlatform.PlatformPublic}
    let tgsCtrl: &TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}

    prepare(acct: AuthAccount) {
        /** --- Borrow TGS Platform Public Resource --- */

        self.tgsPub = TGSPlatform.borrowPlatformPublic()

        /* --- Borrow TGS Platform Contoller --- */

        let ctrlCap = acct
            .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
            (from: TGSPlatform.getStandardControllerPath(acct.address))
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")
        self.tgsCtrl = ctrlCap.borrow()
            ?? panic("Failed to borrow a reference to the TGSPlatform controller")
    }

    pre {
        self.tgsPub.getApplicationAddress(name) != nil: "Application does not exist"
    }

    execute {
        self.tgsCtrl.registerApplicationService(
            self.tgsPub.getApplicationAddress(name)!,
            service: <- PropertyService.createNewService()
        )
        log("PropertyService is registered")
    }
}
