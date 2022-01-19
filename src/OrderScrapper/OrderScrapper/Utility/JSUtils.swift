//
//  JSUtils.swift
//  OrderScrapper

import Foundation

class JSUtils {
    
    static func getAuthErrorVerificationJS() -> String {
        return "(function() { var element = document.getElementById('auth-error-message-box');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return element.getElementsByClassName('a-list-item')[0].innerText;} else {" +
            " return ''}})()"
    }
    
    static func getFieldIdentificationJS() -> String{
        return "(function() { var element = document.getElementById('ap_email_login');" +
            "if (element != null && element.innerHTML !== null) " +
            " { return 'emailId' } else { " +
            " var element = document.getElementById('ap_password');" +
            " if (element != null && element.innerHTML !== null) " +
            " { return 'pwd'} else { return 'other' }}})()"
    }
    
    static func getCaptchaIdentificationJS() -> String {
        return "(function() { var element = document.getElementById('auth-captcha-guess');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'captcha'} else {" +
            " return null}})()"
    }
    
    static func getEmailInjectJS(email: String) -> String {
        return "javascript:" +
            "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
    }
    
    static func getPasswordInjectJS(password: String) -> String {
        return "javascript:" +
            "document.getElementById('ap_password').value = '" + password + "';" +
            "document.getElementById('signInSubmit').click()"
    }
    
    static func getInstacartIdentification() -> String {
        return "var isEmailError, isPasswordError, isFlashError, isRecaptchaVerifyError, isEmailFieldAvailable, isVerification = false; " +
            " const callback = function (mutationsList, observer) { " +
                " for (const mutation of mutationsList) { " +
                   " const el = mutation.target; " +
                   " const verifyEl = document.querySelector('[id*=\"code-\"]'); " +
                    " if (verifyEl && !isVerification) { " +
                        " console.log('Verification screen callback'); " +
                        "    [document.querySelector('[data-testid=\"mobile-close\"]'), document.querySelector('[data-testid=\"back\"]')].forEach(function (item) { " +
                        "      item.addEventListener('click', function () { " +
                        "      window.webkit.messageHandlers.iOS.postMessage(\"verification_closed\");" +
                        "     });" +
                        "     }); " +
                       " isVerification = true; " +
                      " window.webkit.messageHandlers.iOS.postMessage(\"Verification screen callback\"); " +
                   " } " +
                    " if(mutation.type === 'attributes' && mutation.attributeName === 'errortext') { " +
                       " if(el.getAttribute('errortext') && el.getAttribute('errortext').trim() != '') { " +
                          "   console.log('Invalid email or passwrd'); " +
                          " window.webkit.messageHandlers.iOS.postMessage(\"Invalid_user_or_passwrd\"); " +
                       " } " +
                  "  } " +
                   " if (mutation.addedNodes.length) { " +
                       " if (el && el.classList instanceof DOMTokenList) { " +
                            " if (document.querySelector('[data-testid=\"desktop-close\"]')) { " +
                               " const passwordEl = document.querySelector(\"div[id*='error_password']\"); " +
                               " if (passwordEl && passwordEl.textContent.trim() != '' && !isPasswordError) { " +
                                   " console.log('Password error callback'); " +
                                   " isPasswordError = true; " +
                                   " window.webkit.messageHandlers.iOS.postMessage(\"Password error callback\"); " +
                               " } " +
                                " const emailEl = el.querySelector(\"div[id*='error_email']\"); " +
                                " if (emailEl && emailEl.textContent.trim() != '' && !isEmailError) { " +
                                   " console.log('Email error callback'); " +
                                   " isEmailError = true; " +
                                    " window.webkit.messageHandlers.iOS.postMessage(\"Email error callback\"); " +
                                " } " +
                                
                                " if (el.querySelector(\"[data-testid*='flash-message']\") && !isFlashError && " + "el.querySelector(\"[data-testid*='flash-message']\").textContent.trim() != '') { " +
                                    " console.log('Flash message callback'); " +
                                   " isFlashError = true; " +
                                    " window.webkit.messageHandlers.iOS.postMessage(\"Flash message callback\"); " +
                               " } " +
                               " if (el.querySelector(\"input[type='email']\") && !isEmailFieldAvailable) { " +
                                   " console.log('Email field Availablity callback'); " +
                                   " isEmailFieldAvailable = true; " +
                                   " window.webkit.messageHandlers.iOS.postMessage(\"Email field Availablity callback\"); " +
                               " } " +
                               " break; " +
                            " } " +
                       " } " +
                   " } " +

                   " if (mutation.removedNodes.length) { " +
                      "  if (el && el.classList instanceof DOMTokenList) { " +
                           " const removedEl = mutation.removedNodes[0]; " +
                           " const passwordEl = document.querySelector(\"div[id*='error_password']\"); " +
                            " if (passwordEl && passwordEl.textContent.trim() == '' && isPasswordError) { " +
                                // console.log('Password removed error callback', passwordEl);
                               " isPasswordError = false; " +
                            " } " +
                            " const emailEl = el.querySelector(\"div[id*='error_email']\"); " +
                            " if (emailEl && emailEl.textContent.trim() == '' && isEmailError) { " +
                                // console.log('Email removed error callback', emailEl);
                               " isEmailError = false; " +
                            " } " +
                            " const verifyEl = document.querySelector('[id*=\"code-\"]'); " +
                           " if (!verifyEl && isVerification) { " +
                                // console.log('Verification removed screen callback');
                               " isVerification = false; " +
                           " } " +
                           " if (!el.querySelector(\"[data-testid*='flash-message']\") && isFlashError) { " +
                                // console.log('Flash removed message callback', el);
                                " isFlashError = false; " +
                           " } " +
                            " if (!el.querySelector(\"input[type='email']\") && isEmailFieldAvailable) { " +
                                // console.log('Email field removed Availablity callback', el);
                               " isEmailFieldAvailable = false; " +
                           " } " +
                           " break; " +
                        " }  " +
                   " } " +
                " } " +
            " }; " +
           "  var observer = new MutationObserver(callback); " +
           " observer.observe(document.querySelector('body#landing'), { attributes: true, childList: true, characterData: true, subtree: true });"
           }
    
    static func getICinjectLoginJS(email: String, password: String) ->String {
        return " document.querySelector(\"input[type='email']\").value = '" + email + "';" +  "document.querySelector(\"input[type='password']\").value = '" + password + "';" +
            "document.querySelector(\'button[type=\"submit\"]\').click() "
    }
    
    static func getICErrorPasswordInjectJS() ->String {
        return " (function() { var element = document.querySelector(\"div[id*='error_password-']\").innerHTML;if (element == null && element.lenght == 0) {return null} else { return element}})() "
    }
    
    static func getInstacartWrongPasswordInjectJS() ->String {
            return " (function() { var element = document.querySelector('input[type=\"password\"]').getAttribute('errortext');if (element == null && element.length == 0) {return null} else { return element}})() "
        }
    
    static func getICRecaptchaInjectJs() -> String {
        return " (function() { var element = document.querySelector(\"button[id*='recaptcha-verify-button']\");if (element != null && element.innerHTML !== null){return 1} else { return null}})() "
    }
    
    static func getICErrorEmailInjectJS() -> String {
        return " (function() { var element = document.querySelector(\"div[id*='error_email-']\").innerHTML; if (element == null && element.lenght == 0){return null} else { return element }})()"
    }
    
    static func getICFlashMessage() -> String {
        return " (function() { var element = document.querySelector(\"span[data-testid*=\'flash-message\']\").innerHTML;if (element == null && element.lenght == 0){return null} else { return element}})() "
    }
    
    static func getICOnClick() -> String {
        return   " (function() { var element = document.evaluate('//span[text()=\"Log in\"]',document,null," +
            " XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.click(); " +
            " { return \"Log_in\" } })() "
    }
    
    static func getICProcide() -> String {
        return " (function() { var element = document.evaluate('//span[text()=\"Continue in browser\"]',document,null," +    "XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.click();" +
            " { return \"Continue_in_browser\" } })() "
    }
    
    static func getICVerificationCodeJS() -> String {
        return " (function() { var element = " +
            " document.evaluate(\"//h2[contains(text(),'Enter verification code')]\", " +
            " document,null, XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue; " +
            " if (element != undefined) { return \"verification_code\"} } )()"
    }
    
    static func captchaClosed() -> String {
        return "var isClosed = false; " +
            " var callback1 = async function (mutationsList, observer) { " +
            "    for (const mutation of mutationsList) { " +
            "        const el = mutation.target; " +
            "        if (el && el.classList instanceof DOMTokenList) { " +
            "          if(mutation.type === 'attributes' && mutation.target.localName  === 'div' && mutation.attributeName === 'style') { " +
            "                if(el.style.visibility === 'visible') { " +
            "                   console.log('Captcha popup is open'); " +
            "                  isClosed = false; " +
            "                   window.webkit.messageHandlers.iOS.postMessage(\"Captcha_open\"); " +
            "                 break; " +
            "            } else if(el.style.visibility === 'hidden' && !isClosed) { " +
            "               console.log('Capcha closed'); " +
            "               isClosed = true; " +
            "               window.webkit.messageHandlers.iOS.postMessage(\"captcha_closed\"); " +
            "               break; " +
            "  } " +
            "  } " +
            "  } " +
            "  } " +
            "  };" +
            " var observer = new MutationObserver(callback1); " +
            " observer.observe(document.body, { attributes: true, childList: true, characterData: true, subtree: true }); "
    }
    
    static func verificationCodeSuccess() -> String {
        return "(function () {\n" +
                       "    var isVerificationError = false;\n" +
                       "    var verificationCallback = function (mutationsList) {\n" +
                       "        for (const mutation of mutationsList) {\n" +
                       "            if (mutation.removedNodes.length) {\n" +
                       "                const removedEl = mutation.removedNodes[0];\n" +
                       "                const verifyEl = removedEl.querySelector('input[id*=\"code-\"]');\n" +
                       "                const errorEl = removedEl.querySelector('[id*=\"error_code-\"]');\n" +
                       "                console.log('Verification code popup function call');\n" +
                       "                if (verifyEl && verifyEl.value.length === 6 && !errorEl && !isVerificationError) {\n" +
                       "                    console.log('Verification code popup is closed');\n" +
                       "                     window.webkit.messageHandlers.iOS.postMessage(\"verification_success\");" +
                       "                    isVerificationError = true;\n" +
                       "                }\n" +
                       "            }\n" +
                       "        }\n" +
                       "    }\n" +
                       "    var verificationObserver = new MutationObserver(verificationCallback);\n" +
                       "    verificationObserver.observe(document.querySelector('body#landing'), { attributes: true, childList: true, characterData: true, subtree: true });\n" +
                       "})();"

    }
    
    static func getKRIdentifyJSAction() -> String {
        return "(function() { " +
            "  var element = null;" +
            "  element = document.querySelector(\"button[id*='SignIn-submitButton']\");" +
            "  if (element != undefined && element != null " +
            "      && element.innerHTML.length > 0) {" +
            "      return(\"sign_in\"); " +
            "  } " +
            "}) ()"
    }
    
    static func getKRCheckError2Action() -> String {
            return "(function() { " +
                "  var element = null;" +
                "  element = document.evaluate(\"//form[@id='SignIn-form']/div/div/div/span\",document,null," +
                "            XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue;" +
                "  if (element != undefined && element != null " +
                "      && element.innerHTML.length > 0) {" +
                "      return(\"check_error2\"); " +
                "  }else {" +
                "  return null}" +
                "}) ()"
    }
    
    static func getKRIdentifyErrorJSAction() -> String {
        return "(function() { " +
            "  var element = document.querySelector(\"button[id*='SignIn-submitButton']\");" +
            "  if (element != undefined && element != null " +
            "      && element.innerHTML.length > 0) {" +
            "      window.webkit.messageHandlers.iOS.postMessage(\"sign_in\"); " +
            "  } " +
            "let isEmailError, isPasswordError = false;" +
            "const callback = function (mutationsList, observer) {" +
            "    for (const mutation of mutationsList) {" +
            "        const el = mutation.target;" +
            "        if (mutation.type === 'attributes') {" +
            "            if (el && el.classList instanceof DOMTokenList) {" +
            "                if (el.classList.contains('kds-FormField')) {" +
            "                    if (el.classList.contains('is-invalid') && !isEmailError) {" +
            "                    window.webkit.messageHandlers.iOS.postMessage (document.querySelector('#SignIn-errorMessage').textContent); " +
            "                        isEmailError = true;" +
            "                    } else {" +
            "                        isEmailError = false;" +
            "                    }" +
            "                }" +
            "            }" +
            "        }" +
            "" +
            "        if(mutation.type === 'childList') {" +
            "            if (el && el.classList instanceof DOMTokenList) {" +
            "                if(mutation.addedNodes.length) {" +
            "                    if(mutation.addedNodes[0].hasAttribute('id') && mutation.addedNodes[0].getAttribute('id') === 'SignIn-errorMessage' && !isPasswordError) {" +
            "                    window.webkit.messageHandlers.iOS.postMessage (document.querySelector('#SignIn-errorMessage').textContent); " +
            "                        isPasswordError = true;" +
            "                    } else {" +
            "                        isPasswordError = false;" +
            "                    }" +
            "                }" +
            "            }" +
            "        }" +
            "    }" +
            "};" +
            "var observer = new MutationObserver(callback);" +
            "observer.observe(document.querySelector('#SignIn-formContainer'), { attributes: true, childList: true, characterData: true, subtree: true });" +
            "})" +
            "()"
    }
    
    static func getKRSignInJS(email: String, password: String) -> String {
        return "javascript:" +
            "document.querySelector(\"input[id*='SignIn-emailInput']\").value = '" + email + "';" +
            "document.querySelector(\"input[id*='SignIn-passwordInput']\").value = '" + password + "';" +
            "document.querySelector(\"button[id='SignIn-submitButton']\").click()"
    }
    
    static func getKRCheckErrorJS() -> String {
        return "(function() { var element = document.evaluate(\"//div[contains(@id,'SignIn-errorMessage')]/span\",document,null," +
            " XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.innerHTML;" +
            "if (element == null || element.length == 0)" +
            "{return null} else {" +
            "return element}})()"
    }
    
    static func getKRCheckError2JS() -> String {
        return "(function() { var element = document.evaluate(\"//form[@id='SignIn-form']/div/div/div/span\",document,null," +
            "            XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.innerHTML;" +
            "            if (element == null || element.length == 0)" +
            "            {return null} else {" +
            "            return element}})()"
    }
    
    static func getWAVerifyIdentityJS() -> String {
        return " (function() { var element = " +
            " document.evaluate(\"//p[contains(text(),'Press & Hold')]\", " +
            " document,null, XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue; " +
            " if (element != undefined) { return \"verify_identity\"} } )()"
    }
    
    static func getWACheckErrorJS() -> String {
        return "(function() { var element = document.evaluate(\"//div[contains(@id,'global-error')]\",document,null," +
            " XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue.textContent;" +
            "if (element == null || element.length == 0)" +
            "{return null} else {" +
            "return element}})()"
    }
    
    static func getWalmartIdentificationJS(email: String, password: String) -> String {
        return " if(window.location.href.indexOf('blocked') > -1) { " +
            // Captcha is open
            " window.webkit.messageHandlers.iOS.postMessage(\"verify_identity\");" +
       " } " +

        // When password page is shown
        // When Account login page is shown
        " if(window.location.href.indexOf('account/login') > -1) { " +
           " if(document.querySelector('#email') && document.querySelector('#password')) { " +
            " document.querySelector(\"input[id*='email']\").value = '" + email + "';" +
            " document.querySelector(\"input[id*='password']\").value = '" + password + "';" +
            " document.querySelector(\"button[data-automation-id='signin-submit-btn']\").click();" +
            " window.webkit.messageHandlers.iOS.postMessage(\"sign_in\"); " +
          " } else { " +
            " document.querySelector(\"input[id*='email']\").value = '" + email + "';" +
            " document.querySelector(\"button[data-automation-id='signin-continue-submit-btn']\").click();" +

                 " setTimeout(function() { " +
                    " document.querySelector('#sign-in-password-no-otp').value = '" + password + "';" +
                    " document.querySelectorAll('[data-automation-id=\"sign-in-pwd\"]')[1].click(); " +
                 " }, 2000) " +
          " } " +
        " } " +
        // SignIn Error message callback
       " const signInCallback = async function (mutationsList, observer) { " +
           " for (const mutation of mutationsList) { " +
                // console.log('Mutation ', mutation);
              "  if(mutation.type === 'childList') { " +
                 "   if(mutation.addedNodes.length) { " +
                       " window.webkit.messageHandlers.iOS.postMessage(\"Validation error is shown\"); " +
                   " } " +
               " } " +
          "  } " +
       " }; " +
       " const signInObserver = new MutationObserver(signInCallback); " +
       " signInObserver.observe(document.querySelector('#global-error'), { attributes: true, childList: true, characterData: false, subtree: true }); " +

        // Captcha page Callback
      "  var isCaptchaError = false; " +
       " var captchaCallback = async function (mutationsList, observer) { " +
          "  for (const mutation of mutationsList) { " +
              "  var el = mutation.target; " +
                // console.log('Mutation ', mutation);
               " if(mutation.addedNodes.length) { " +
                  "  if(mutation.type === 'childList') { " +
                       " if((el.hasAttribute('id') && el.getAttribute('id') === 'px-captcha') && !isCaptchaError) { " +
                           " window.webkit.messageHandlers.iOS.postMessage(\"Captcha is open\"); " +
                           " isCaptchaError = true; " +
                       " } " +
                   " } " +
               " } " +

               " if (mutation.removedNodes.length) { " +
                   " mutation.removedNodes.forEach(function(removedEl) { " +
                       " if(removedEl.classList instanceof DOMTokenList) { " +
               "if((removedEl.hasAttribute('id') && removedEl.getAttribute('id') === 'px-captcha') || removedEl.querySelector('#px-captcha')) { " +
                               " window.webkit.messageHandlers.iOS.postMessage(\"Captcha is closed\"); " +
                              "  isCaptchaError = false; " +
                          "  } " +
                      "  } " +
                    " }); " +
              "  } " +
                 
           " } " +
       " }; " +
       " var captchaObserver = new MutationObserver(captchaCallback); " +
       " captchaObserver.observe(document.body, { attributes: true, childList: true, characterData: false, subtree: true }); "
    }
    
    static func getWalmartSignInRequiredJS() -> String {
        return "Boolean(document.evaluate(\"//*[contains(text(),'Sign in')]\", document, null, XPathResult.ANY_TYPE,null).iterateNext())"
    }
}
