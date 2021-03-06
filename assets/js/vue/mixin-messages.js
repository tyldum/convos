(function() {
  var offset = 60;

  Convos.mixin.messages = {
    data: function() {
      return {atBottom: true, scrollElement: null};
    },
    watch: {
      "dialog.active": function(v, o) {
        if (v === false && o === true) this.deactivate();
        if (v === true) this.activate();
      }
    },
    methods: {
      activate: function() {
        this.dialog.activate();
        if (this._atBottomTid) return;
        this._atBottomTid = setInterval(this.keepAtBottom, 200);
      },
      deactivate: function() {
        this.dialog.setLastRead();
        if (this._atBottomTid) clearTimeout(this._atBottomTid);
        delete this._atBottomTid;
      },
      findVisibleMessage: function() {
        var messages = this.scrollElement.querySelectorAll(".convos-message");
        var st = this.scrollElement.scrollTop;
        var n = 0;
        while (++n < messages.length) {
          if (messages[n].offsetTop >= st) return messages[n];
        }
        return null;
      },
      keepAtBottom: function() {
        var el = this.scrollElement;
        if (!this.atBottom) return;
        if (el.scrollTop > el.scrollHeight - el.offsetHeight - 10) return;
        this.scrollTid = "lock"; // need to prevent the next onScroll() call triggered by scrollTop below
        el.scrollTop = el.scrollHeight;
      },
      onScroll: function() {
        if (this.scrollTid == "lock") return this.scrollTid = 0;
        if (this.scrollTid) return;
        this.scrollTid = setTimeout(function() {
          var msgEl, el = this.scrollElement;

          this.scrollTid = 0;
          this.atBottom = el.scrollTop > el.scrollHeight - el.offsetHeight - offset;

          if (el.scrollTop < offset) {
            var msgEl = this.findVisibleMessage();
            this.dialog.load({historic: true}, function(err, body) {
              if (msgEl) window.nextTick(function() { el.scrollTop = msgEl.offsetTop; });
            });
          }
        }.bind(this), 100);
      }
    },
    ready: function() {
      this.scrollElement = this.$el.querySelector(".scroll-element");
      this.scrollElement.addEventListener("scroll", this.onScroll);
      // Need to use $nextTick, since the "message" event is triggered before the element is rendered on the page
      this.dialog.on("message", function() { this.$nextTick(this.keepAtBottom); }.bind(this));
    },
    beforeDestroy: function() {
      this.scrollElement.removeEventListener("scroll", this.onScroll);
    }
  };
})();
