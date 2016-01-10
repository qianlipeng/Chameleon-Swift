/*
 * Copyright (c) 2013, The Iconfactory. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Neither the name of The Iconfactory nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE ICONFACTORY BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
import AppKit
import AppKit
// when the shim gets asked if it can respond to a method, it asks the delegate's responder if it can respond
// to it or not
//
// if the shim is sent a message that it needs to forward, it uses the delegate's responder as a starting point
// and walks the responder chain until it finds the responder to send it to. if it turns out the responder
// returned cannot respond to the selector, it eventually ends up with a doesNotRecognizeSelector exception.
//
// the shim also implements NSUserInterfaceValidations by sending it's responder -canPerformAction:withSender:
// messages for proposed actions. if the responder says it can perform the action, it validates. this allows
// native OSX menus and toolbars to reach down into the UIKit responder chain and enable/disable accordingly.

protocol UINSResponderShimDelegate: NSObject {
    func responderForResponderShim(shim: UINSResponderShim) -> UIResponder
}
class UINSResponderShim: NSResponder, NSUserInterfaceValidations {
    weak var delegate: UINSResponderShimDelegate

    func methodSignatureForSelector(aSelector: Selector, withResponder responder: UIResponder) -> NSMethodSignature {
        for ; responder != nil; responder = responder.nextResponder() {
            var sig: NSMethodSignature = responder.methodSignatureForSelector(aSelector)
            if sig != nil {
                return sig
            }
        }
        return nil
    }

    func respondsToSelector(aSelector: Selector) -> Bool {
        if super.respondsToSelector(aSelector) {
            return true
        }
        return (self.methodSignatureForSelector(aSelector, withResponder: self.delegate.responderForResponderShim(self)) != nil)
    }

    func methodSignatureForSelector(aSelector: Selector) -> NSMethodSignature {
        var sig: NSMethodSignature = super.methodSignatureForSelector(aSelector)
        if !sig {
            sig = self.methodSignatureForSelector(aSelector, withResponder: self.delegate.responderForResponderShim(self))
        }
        return sig
    }

    func forwardInvocation(anInvocation: NSInvocation) {
        for var responder = self.delegate.responderForResponderShim(self); responder != nil; responder = responder.nextResponder() {
            if responder.respondsToSelector(anInvocation.selector()) {
                anInvocation.invokeWithTarget(responder)
                return
            }
        }
        super.forwardInvocation(anInvocation)
    }

    func validateUserInterfaceItem(anItem: NSValidatedUserInterfaceItem) -> Bool {
        return self.delegate.responderForResponderShim(self).canPerformAction(anItem.action(), withSender: nil)
    }
}