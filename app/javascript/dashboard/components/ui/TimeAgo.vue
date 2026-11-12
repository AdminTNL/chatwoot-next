<script>
import { startOfTomorrow } from 'date-fns';
import {
  conversationActivityTime,
  conversationActivityDateTime,
} from 'shared/helpers/timeHelper';

export default {
  name: 'TimeAgo',
  props: {
    isAutoRefreshEnabled: {
      type: Boolean,
      default: true,
    },
    lastActivityTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    conversationId: {
      type: [String, Number],
      default: '',
    },
  },
  data() {
    return {
      timer: null,
      now: Date.now(),
    };
  },
  computed: {
    lastActivityTime() {
      return conversationActivityTime(
        this.lastActivityTimestamp,
        this.$i18n.locale,
        new Date(this.now)
      );
    },
    tooltipText() {
      return `${this.$t(
        'CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE'
      )} ${conversationActivityDateTime(
        this.lastActivityTimestamp,
        this.$i18n.locale
      )}`;
    },
  },
  watch: {
    lastActivityTimestamp() {
      // A late timer (background tab, sleep) may have left `now` on a past day.
      this.now = Date.now();
    },
    conversationId() {
      // Reset display values and timer when the row is recycled to a different conversation.
      this.now = Date.now();
      if (this.isAutoRefreshEnabled) {
        clearTimeout(this.timer);
        this.createTimer();
      }
    },
  },
  mounted() {
    if (this.isAutoRefreshEnabled) {
      this.createTimer();
    }
  },
  unmounted() {
    clearTimeout(this.timer);
  },
  methods: {
    createTimer() {
      this.timer = setTimeout(() => {
        this.now = Date.now();
        this.createTimer();
      }, this.refreshTime());
    },
    refreshTime() {
      // The label only changes when the day changes ("14:32" -> "Yesterday" -> date).
      return startOfTomorrow().getTime() - Date.now() + 1000;
    },
  },
};
</script>

<template>
  <div
    v-tooltip.top="{
      content: tooltipText,
      delay: { show: 1000, hide: 0 },
    }"
    class="ml-auto leading-4 text-xxs text-n-slate-10 hover:text-n-slate-11"
  >
    <span>{{ lastActivityTime }}</span>
  </div>
</template>
