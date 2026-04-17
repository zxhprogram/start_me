package handlers

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-resty/resty/v2"
	"start_me_backend/models"
)

// WMO weather code -> 中文描述
var weatherCodeMap = map[int]string{
	0:  "晴",
	1:  "少云",
	2:  "多云",
	3:  "阴",
	45: "雾",
	48: "霜雾",
	51: "小毛毛雨",
	53: "毛毛雨",
	55: "大毛毛雨",
	56: "冻毛毛雨",
	57: "冻毛毛雨",
	61: "小雨",
	63: "中雨",
	65: "大雨",
	66: "冻雨",
	67: "冻雨",
	71: "小雪",
	73: "中雪",
	75: "大雪",
	77: "雪粒",
	80: "小阵雨",
	81: "阵雨",
	82: "大阵雨",
	85: "小阵雪",
	86: "大阵雪",
	95: "雷暴",
	96: "雷暴冰雹",
	99: "强雷暴冰雹",
}

// WMO weather code -> icon 名称
var weatherIconMap = map[int]string{
	0:  "wb_sunny",
	1:  "partly_cloudy",
	2:  "cloud",
	3:  "cloud",
	45: "foggy",
	48: "foggy",
	51: "grain",
	53: "grain",
	55: "grain",
	56: "grain",
	57: "grain",
	61: "water_drop",
	63: "water_drop",
	65: "water_drop",
	66: "water_drop",
	67: "water_drop",
	71: "ac_unit",
	73: "ac_unit",
	75: "ac_unit",
	77: "ac_unit",
	80: "water_drop",
	81: "water_drop",
	82: "water_drop",
	85: "ac_unit",
	86: "ac_unit",
	95: "thunderstorm",
	96: "thunderstorm",
	99: "thunderstorm",
}

func getWeatherDesc(code int) string {
	if desc, ok := weatherCodeMap[code]; ok {
		return desc
	}
	return "未知"
}

func getWeatherIcon(code int) string {
	if icon, ok := weatherIconMap[code]; ok {
		return icon
	}
	return "cloud"
}

// 风向角度 -> 中文
func getWindDir(deg float64) string {
	dirs := []string{"北风", "东北风", "东风", "东南风", "南风", "西南风", "西风", "西北风"}
	idx := int(math.Round(deg/45.0)) % 8
	return dirs[idx]
}

// 风速(km/h) -> 风力等级
func getWindLevel(speed float64) string {
	switch {
	case speed < 1:
		return "0级"
	case speed < 6:
		return "1级"
	case speed < 12:
		return "2级"
	case speed < 20:
		return "3级"
	case speed < 29:
		return "4级"
	case speed < 39:
		return "5级"
	case speed < 50:
		return "6级"
	case speed < 62:
		return "7级"
	case speed < 75:
		return "8级"
	default:
		return "9级以上"
	}
}

// AQI -> 等级描述
func getAQILevel(aqi int) string {
	switch {
	case aqi <= 50:
		return "优"
	case aqi <= 100:
		return "良"
	case aqi <= 150:
		return "轻度污染"
	case aqi <= 200:
		return "中度污染"
	case aqi <= 300:
		return "重度污染"
	default:
		return "严重污染"
	}
}

// 生活建议
func getWeatherTip(code int, aqi int) string {
	if aqi > 150 {
		return "空气质量较差，建议减少户外活动，出门佩戴口罩。"
	}
	switch {
	case code == 0 || code == 1:
		return "各类人群可多参加户外活动，多呼吸一下清新的空气。"
	case code == 2 || code == 3:
		return "天气较好，适宜户外活动。"
	case code >= 45 && code <= 48:
		return "有雾天气，出行注意安全，驾车减速慢行。"
	case code >= 51 && code <= 67:
		return "有降雨，出行请携带雨具，注意路面湿滑。"
	case code >= 71 && code <= 86:
		return "有降雪，注意防寒保暖，出行注意路面结冰。"
	case code >= 95:
		return "雷暴天气，尽量减少外出，远离高大建筑和树木。"
	default:
		return "天气状况一般，外出请注意适当防护。"
	}
}

// 星期映射
var weekdayMap = map[time.Weekday]string{
	time.Monday:    "周一",
	time.Tuesday:   "周二",
	time.Wednesday: "周三",
	time.Thursday:  "周四",
	time.Friday:    "周五",
	time.Saturday:  "周六",
	time.Sunday:    "周日",
}

// GetWeather 获取天气数据
func GetWeather(c *gin.Context) {
	lat := c.DefaultQuery("lat", "39.8585")
	lon := c.DefaultQuery("lon", "116.2867")
	location := c.DefaultQuery("location", "北京市·丰台")

	client := resty.New().SetTimeout(10 * time.Second)

	var weatherBody, aqiBody []byte
	var weatherErr, aqiErr error
	var wg sync.WaitGroup

	// 并行请求天气和空气质量
	wg.Add(2)
	go func() {
		defer wg.Done()
		resp, err := client.R().
			SetQueryParams(map[string]string{
				"latitude":       lat,
				"longitude":      lon,
				"current":        "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,precipitation",
				"hourly":         "temperature_2m,weather_code",
				"daily":          "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
				"timezone":       "Asia/Shanghai",
				"forecast_hours": "24",
				"forecast_days":  "7",
			}).
			Get("https://api.open-meteo.com/v1/forecast")
		if err != nil {
			weatherErr = err
			return
		}
		weatherBody = resp.Body()
	}()

	go func() {
		defer wg.Done()
		resp, err := client.R().
			SetQueryParams(map[string]string{
				"latitude":  lat,
				"longitude": lon,
				"current":   "us_aqi",
				"timezone":  "Asia/Shanghai",
			}).
			Get("https://air-quality-api.open-meteo.com/v1/air-quality")
		if err != nil {
			aqiErr = err
			return
		}
		aqiBody = resp.Body()
	}()

	wg.Wait()

	if weatherErr != nil {
		c.JSON(http.StatusOK, models.WeatherResponse{
			Success: false,
			Error:   "获取天气失败: " + weatherErr.Error(),
		})
		return
	}

	// 解析天气数据
	var weatherResult map[string]interface{}
	if err := json.Unmarshal(weatherBody, &weatherResult); err != nil {
		c.JSON(http.StatusOK, models.WeatherResponse{
			Success: false,
			Error:   "解析天气数据失败: " + err.Error(),
		})
		return
	}

	// 解析当前天气
	current, _ := weatherResult["current"].(map[string]interface{})
	temp, _ := current["temperature_2m"].(float64)
	humidity, _ := current["relative_humidity_2m"].(float64)
	weatherCode := int(getFloat(current, "weather_code"))
	windSpeed, _ := current["wind_speed_10m"].(float64)
	windDir, _ := current["wind_direction_10m"].(float64)
	pressure, _ := current["surface_pressure"].(float64)
	precip, _ := current["precipitation"].(float64)
	currentTime, _ := current["time"].(string)

	// 解析 AQI
	aqi := 0
	if aqiErr == nil && aqiBody != nil {
		var aqiResult map[string]interface{}
		if err := json.Unmarshal(aqiBody, &aqiResult); err == nil {
			if aqiCurrent, ok := aqiResult["current"].(map[string]interface{}); ok {
				aqi = int(getFloat(aqiCurrent, "us_aqi"))
			}
		}
	}

	// 解析逐时预报
	var hourlyList []models.WeatherHourly
	if hourly, ok := weatherResult["hourly"].(map[string]interface{}); ok {
		times, _ := hourly["time"].([]interface{})
		temps, _ := hourly["temperature_2m"].([]interface{})
		codes, _ := hourly["weather_code"].([]interface{})

		for i := 0; i < len(times) && i < 24; i++ {
			t, _ := times[i].(string)
			tmpVal := getFloatFromSlice(temps, i)
			codeVal := int(getFloatFromSlice(codes, i))

			// 提取小时
			hour := ""
			if len(t) >= 13 {
				hour = t[11:13] + "时"
			}

			hourlyList = append(hourlyList, models.WeatherHourly{
				Time:        t,
				Hour:        hour,
				Temp:        tmpVal,
				WeatherCode: codeVal,
				Weather:     getWeatherDesc(codeVal),
				WeatherIcon: getWeatherIcon(codeVal),
			})
		}
	}

	// 解析每日预报
	var dailyList []models.WeatherDaily
	if daily, ok := weatherResult["daily"].(map[string]interface{}); ok {
		dates, _ := daily["time"].([]interface{})
		codes, _ := daily["weather_code"].([]interface{})
		maxTemps, _ := daily["temperature_2m_max"].([]interface{})
		minTemps, _ := daily["temperature_2m_min"].([]interface{})
		sunrises, _ := daily["sunrise"].([]interface{})
		sunsets, _ := daily["sunset"].([]interface{})

		loc, _ := time.LoadLocation("Asia/Shanghai")

		for i := 0; i < len(dates); i++ {
			dateStr, _ := dates[i].(string)
			codeVal := int(getFloatFromSlice(codes, i))
			maxT := getFloatFromSlice(maxTemps, i)
			minT := getFloatFromSlice(minTemps, i)
			sunrise := ""
			sunset := ""
			if i < len(sunrises) {
				if s, ok := sunrises[i].(string); ok && len(s) >= 16 {
					sunrise = s[11:16]
				}
			}
			if i < len(sunsets) {
				if s, ok := sunsets[i].(string); ok && len(s) >= 16 {
					sunset = s[11:16]
				}
			}

			// 计算星期
			dayOfWeek := ""
			displayDate := ""
			if t, err := time.ParseInLocation("2006-01-02", dateStr, loc); err == nil {
				now := time.Now().In(loc)
				if t.Format("2006-01-02") == now.Format("2006-01-02") {
					dayOfWeek = "今天"
				} else if t.Format("2006-01-02") == now.AddDate(0, 0, 1).Format("2006-01-02") {
					dayOfWeek = "明天"
				} else {
					dayOfWeek = weekdayMap[t.Weekday()]
				}
				displayDate = fmt.Sprintf("%02d-%02d", t.Month(), t.Day())
			}

			dailyList = append(dailyList, models.WeatherDaily{
				Date:        displayDate,
				DayOfWeek:   dayOfWeek,
				WeatherCode: codeVal,
				Weather:     getWeatherDesc(codeVal),
				WeatherIcon: getWeatherIcon(codeVal),
				TempMax:     maxT,
				TempMin:     minT,
				Sunrise:     sunrise,
				Sunset:      sunset,
			})
		}
	}

	// 构建响应
	data := &models.WeatherData{
		Location: location,
		Current: models.WeatherCurrent{
			Temp:        temp,
			Humidity:    int(humidity),
			WeatherCode: weatherCode,
			Weather:     getWeatherDesc(weatherCode),
			WeatherIcon: getWeatherIcon(weatherCode),
			WindSpeed:   windSpeed,
			WindDir:     getWindDir(windDir),
			WindLevel:   getWindLevel(windSpeed),
			Pressure:    math.Round(pressure),
			Precip:      precip,
			AQI:         aqi,
			AQILevel:    getAQILevel(aqi),
			Time:        currentTime,
		},
		Hourly: hourlyList,
		Daily:  dailyList,
		Tip:    getWeatherTip(weatherCode, aqi),
	}

	c.JSON(http.StatusOK, models.WeatherResponse{
		Success: true,
		Data:    data,
	})
}

// SearchCity 搜索城市
func SearchCity(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusOK, models.CitySearchResponse{
			Success: false,
			Error:   "请输入城市名",
		})
		return
	}

	client := resty.New().SetTimeout(10 * time.Second)
	resp, err := client.R().
		SetQueryParams(map[string]string{
			"name":     query,
			"count":    "10",
			"language": "zh",
		}).
		Get("https://geocoding-api.open-meteo.com/v1/search")

	if err != nil {
		c.JSON(http.StatusOK, models.CitySearchResponse{
			Success: false,
			Error:   "搜索失败: " + err.Error(),
		})
		return
	}

	var result map[string]interface{}
	if err := json.Unmarshal(resp.Body(), &result); err != nil {
		c.JSON(http.StatusOK, models.CitySearchResponse{
			Success: false,
			Error:   "解析失败: " + err.Error(),
		})
		return
	}

	results, _ := result["results"].([]interface{})
	var cities []models.CitySearchResult
	for _, r := range results {
		item, _ := r.(map[string]interface{})
		name, _ := item["name"].(string)
		country, _ := item["country"].(string)
		admin1, _ := item["admin1"].(string)
		lat := getFloat(item, "latitude")
		lon := getFloat(item, "longitude")

		cities = append(cities, models.CitySearchResult{
			Name:    name,
			Country: country,
			Admin1:  admin1,
			Lat:     lat,
			Lon:     lon,
		})
	}

	c.JSON(http.StatusOK, models.CitySearchResponse{
		Success: true,
		Data:    cities,
	})
}

func getFloat(m map[string]interface{}, key string) float64 {
	if v, ok := m[key].(float64); ok {
		return v
	}
	return 0
}

func getFloatFromSlice(s []interface{}, i int) float64 {
	if i < len(s) {
		if v, ok := s[i].(float64); ok {
			return v
		}
	}
	return 0
}
