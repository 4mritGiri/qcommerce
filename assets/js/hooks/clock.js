export default {
  mounted() {
    this.timer = setInterval(() => this.update(), 1000)
    this.update()
  },

  destroyed() {
    clearInterval(this.timer)
  },

  update() {
    const now = new Date()

    const seconds = now.getSeconds() * 6
    const minutes = now.getMinutes() * 6 + now.getSeconds() * 0.1
    const hours = (now.getHours() % 12) * 30 + now.getMinutes() * 0.5

    const secondHand = this.el.querySelector('[data-hand="second"]')
    const minuteHand = this.el.querySelector('[data-hand="minute"]')
    const hourHand = this.el.querySelector('[data-hand="hour"]')

    secondHand?.setAttribute("transform", `rotate(${seconds} 12 12)`)
    minuteHand?.setAttribute("transform", `rotate(${minutes} 12 12)`)
    hourHand?.setAttribute("transform", `rotate(${hours} 12 12)`)
  }
}