(function() {
  window.isMobile = navigator.userAgent.match(/Android|iPad|iPhone|iPod|webOS|Windows Phone/i);
  window.isTouchDevice = !!("ontouchstart" in window);
  window.DEBUG = window.DEBUG || true; // TODO: Should default to false?

  window.nextTick = function(cb) { setTimeout(cb, 1); };

  NodeList.prototype.$forEach = Array.prototype.forEach;

  Date.fromAPI = function(t) {
    if (!t) return new Date();
    if (!t.match(/Z$/)) t += "Z"
    return new Date(t);
  };

  Element.prototype.$remove = function() {
    this.parentElement.removeChild(this);
  };

  Element.prototype.focusOnDesktop = function() {
    var elem = this;
    if (!isMobile) window.nextTick(function() { elem.focus(); });
  };

  if (!Object.values) {
    Object.values = function(obj) {
      return Object.keys(obj).map(function(k) { return obj[k]; });
    };
  }

  RegExp.escape = function(text) {
    return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
  };

  // Based on https://gist.github.com/jonathantneal/3748027
  if (!window.addEventListener) {
    var wp = Window.prototype;
    var dp = HTMLDocument.prototype;
    var ep = Element.prototype;
    var registry = [];

    wp.addEventListener = dp.addEventListener = ep.addEventListener = function(type, listener) {
      var target = this;

      registry.unshift([target, type, listener, function(event) {
        event.currentTarget = target;
        event.preventDefault = function() { event.returnValue = false; };
        event.stopPropagation = function() { event.cancelBubble = true; };
        event.target = event.srcElement || target;
        listener.call(target, event);
      }]);

      this.attachEvent("on" + type, registry[0][3]);
    };

    wp.removeEventListener = dp.removeEventListener = ep.removeEventListener = function(type, listener) {
      for (var index = 0, register; register = registry[index]; ++index) {
        if (register[0] == this && register[1] == type && register[2] == listener) {
          return this.detachEvent("on" + type, registry.splice(index, 1)[0][3]);
        }
      }
    };

    wp.dispatchEvent = dp.dispatchEvent = ep.dispatchEvent = function(eventObject) {
      return this.fireEvent("on" + eventObject.type, eventObject);
    };
  }

  if (typeof window.CustomEvent != "function") {
    function CustomEvent(event, params) {
      params = params || {bubbles: false, cancelable: false, detail: undefined};
      var evt = document.createEvent('CustomEvent');
      evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail);
      return evt;
    }

    CustomEvent.prototype = window.Event.prototype;
    window.CustomEvent = CustomEvent;
  }
})();
