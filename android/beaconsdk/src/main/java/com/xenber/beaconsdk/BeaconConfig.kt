package com.xenber.beaconsdk

data class BeaconConfig (

  val gatewayUrl: String,
  val dataUrl: String,
  val userId: String,
  //val authToken: String, 
  val rssiThreshold: Int = -85,
  val timeThreshold: Int = 2,
  val scanPeriod: Long = 1100L,
  val betweenScanPeriod: Long = 5000L,
  val notificationCooldown: Long = 3000L,
  val maxNotifications: Int = 3

) {

  init {
    require(gatewayUrl.startsWith("http")) {"Invalid gateway URL"}
    require(dataUrl.startsWith("http")) {"Invalid data URL"}
    require(userId.isNotBlank()) {"User ID Missing"}
    //require(authToken.isNotBlank()) {"Auth Token Missing"}
  }
}