class WebElement(object):
  @staticmethod
  def create_ff_profile(path):
    from selenium import webdriver
    profile = webdriver.FirefoxProfile(path)
    #profile = webdriver.FirefoxProfile('/tmp')
    profile.set_preference("browser.download.folderList", 2)
    profile.set_preference("browser.download.dir", path)
    profile.set_preference('intl.accept_languages', 'es')
    profile.set_preference("browser.download.manager.alertOnEXEOpen", False)
    profile.set_preference("browser.helperApps.neverAsk.saveToDisk", "application/x-rar-compressed,text/csv,application/octet-stream,application/java-archive,application/x-msexcel,application/excel,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/x-excel,application/vnd.ms-excel,image/png,image/jpeg,text/html,text/plain,application/msword,application/xml,application/vnd.microsoft.portable-executable")
    profile.set_preference("browser.download.manager.showWhenStarting", False)
    profile.set_preference("browser.download.manager.focusWhenStarting", False)
    profile.set_preference("browser.download.useDownloadDir", True)
    profile.set_preference("browser.helperApps.alwaysAsk.force", False)
    profile.set_preference("browser.download.manager.alertOnEXEOpen", False)
    profile.set_preference("browser.download.manager.closeWhenDone", True)
    profile.set_preference("browser.download.manager.showAlertOnComplete", False)
    profile.set_preference("browser.download.manager.useWindow", False)
    profile.set_preference("services.sync.prefs.sync.browser.download.manager.showWhenStarting", False)
    profile.set_preference("pdfjs.disabled", True)
    profile.update_preferences()
    return profile.path
