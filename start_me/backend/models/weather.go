package models

// WeatherCurrent 当前天气
type WeatherCurrent struct {
	Temp        float64 `json:"temp"`
	Humidity    int     `json:"humidity"`
	WeatherCode int     `json:"weather_code"`
	Weather     string  `json:"weather"`
	WeatherIcon string  `json:"weather_icon"`
	WindSpeed   float64 `json:"wind_speed"`
	WindDir     string  `json:"wind_dir"`
	WindLevel   string  `json:"wind_level"`
	Pressure    float64 `json:"pressure"`
	Precip      float64 `json:"precip"`
	AQI         int     `json:"aqi"`
	AQILevel    string  `json:"aqi_level"`
	Time        string  `json:"time"`
}

// WeatherHourly 逐时天气
type WeatherHourly struct {
	Time        string  `json:"time"`
	Hour        string  `json:"hour"`
	Temp        float64 `json:"temp"`
	WeatherCode int     `json:"weather_code"`
	Weather     string  `json:"weather"`
	WeatherIcon string  `json:"weather_icon"`
}

// WeatherDaily 每日天气
type WeatherDaily struct {
	Date        string  `json:"date"`
	DayOfWeek   string  `json:"day_of_week"`
	WeatherCode int     `json:"weather_code"`
	Weather     string  `json:"weather"`
	WeatherIcon string  `json:"weather_icon"`
	TempMax     float64 `json:"temp_max"`
	TempMin     float64 `json:"temp_min"`
	Sunrise     string  `json:"sunrise"`
	Sunset      string  `json:"sunset"`
}

// WeatherResponse 天气响应
type WeatherResponse struct {
	Success bool         `json:"success"`
	Data    *WeatherData `json:"data,omitempty"`
	Error   string       `json:"error,omitempty"`
}

// WeatherData 完整天气数据
type WeatherData struct {
	Location string          `json:"location"`
	Current  WeatherCurrent  `json:"current"`
	Hourly   []WeatherHourly `json:"hourly"`
	Daily    []WeatherDaily  `json:"daily"`
	Tip      string          `json:"tip"`
}

// CitySearchResult 城市搜索结果
type CitySearchResult struct {
	Name    string  `json:"name"`
	Country string  `json:"country"`
	Admin1  string  `json:"admin1"`
	Lat     float64 `json:"lat"`
	Lon     float64 `json:"lon"`
}

// CitySearchResponse 城市搜索响应
type CitySearchResponse struct {
	Success bool               `json:"success"`
	Data    []CitySearchResult `json:"data,omitempty"`
	Error   string             `json:"error,omitempty"`
}
