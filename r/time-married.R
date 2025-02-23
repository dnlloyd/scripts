library(lubridate)

wedding_date <- as.Date('2010-12-31')
current_date <- as.Date(now())

time_married <- current_date - wedding_date

# print(typeof(time_married))

print(time_married)

if (time_married > 1000 ) {
    print("You've been married a long time")
} else {
    print("You'll get there")
}
