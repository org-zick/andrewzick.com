// from here https://stackoverflow.com/a/11252167
function treatAsUTC(date) {
    var result = new Date(date);
    result.setMinutes(result.getMinutes() - result.getTimezoneOffset());
    return result;
}

function daysBetween(startDate, endDate) {
    var millisecondsPerDay = 24 * 60 * 60 * 1000;
    return Math.floor((treatAsUTC(endDate) - treatAsUTC(startDate)) / millisecondsPerDay);
}

function getDayOfTheYear(inputDate) {
    var start = new Date(inputDate.getFullYear(), 0, 0);
    var diff = (inputDate - start) + ((start.getTimezoneOffset() - inputDate.getTimezoneOffset()) * 60 * 1000);
    var oneDay = 1000 * 60 * 60 * 24;
    var day = Math.floor(diff / oneDay);
    return day;
}
