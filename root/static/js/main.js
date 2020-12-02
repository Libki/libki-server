/* This js is valid for both staff and public interfaces */
$(document).ready(function(){
    const hourSelector = document.querySelector('#reservation-hour');
    if ( hourSelector ) {
        hourSelector.addEventListener('change', (event) => {
            validateReservationTime();
        });
    }
});

function validateReservationTime() {
    if ( isHourSlotReservable() ) {
        enableMakeReservation();
    } else {
        disableMakeReservation();
    }
}

function isHourSlotReservable() {
    const reservation_minute = document.querySelector('#reservation-minute');
    return reservation_minute.selectedIndex != -1;
}

function disableMakeReservation() {
    const btn = document.querySelector('#make-reservation-modal-form-submit');
    btn.setAttribute("disabled", "disabled");
    document.querySelector('#reservation-time-invalid-feedback').style.display = "block";
}

function enableMakeReservation() {
    const btn = document.querySelector('#make-reservation-modal-form-submit');
    btn.removeAttribute("disabled");
    document.querySelector('#reservation-time-invalid-feedback').style.display = "none";
}

function AddTableRowToolbar($toolbar, $table, $rows) {
    $rows.mouseenter(function() {
        $toolbar.slideDown().position({
            of: $(this),
            my: "left top",
            at: "left bottom",
        });
        window.selected_id = $(this).attr("id");
    });

}

function isToday() {
    var date = new Date();
    var dateTime = document.getElementById("datepicker");
    var nowMonth = date.getMonth() + 1;
    var strDate = date.getDate();
    var seperator = "-";
    if (nowMonth >= 1 && nowMonth <= 9) {
        nowMonth = "0" + nowMonth;
    }
    if (strDate >= 0 && strDate <= 9) {
        strDate = "0" + strDate;
    }
    var nowDate = date.getFullYear() + seperator + nowMonth + seperator + strDate;
    if (nowDate == dateTime.value)
        return true;
    else
        return false;
}

function setHour() {
    $("#reservation-hour").empty();
    var selecthour = document.getElementById("reservation-hour");
    var hours = ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23"];
    var date = new Date();
    var minute = date.getMinutes();
    var i = 0;
    if (isToday()) {
        i = date.getHours();
        if (minute >= 55) {
            i = i + 1;
        }
    }
    for (i; i < hours.length; i++) {
        var opt = hours[i];
        var el = document.createElement("option");
        el.textContent = opt;
        el.value = opt;
        selecthour.appendChild(el);
    }
}

function setMinute() {
    $("#reservation-minute").empty();
    var selectminute = document.getElementById("reservation-minute");
    var selecthour = document.getElementById("reservation-hour");
    var minutes = ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"];
    var i = 0;
    var date = new Date();
    var hour = date.getHours();

    if (hour <= 9) {
        hour = "0" + hour;
    }

    if (isToday() && hour == selecthour.value) {
        i = parseInt(date.getMinutes() / 5) + 1;
    }

    for (i; i < minutes.length; i++) {
        var opt = minutes[i];
        var el = document.createElement("option");
        el.textContent = opt;
        el.value = opt;
        selectminute.appendChild(el);
    }
}

function setTime() {
    setHour();
    setMinute();
    enableMakeReservation();
    validateReservationTime();
}

var minutes = ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"];
var hours = ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23"];
var mlist;

function getMinute() {
    $("#reservation-minute").empty();
    var selectminute = document.getElementById("reservation-minute");
    var selecthour = document.getElementById("reservation-hour");
    var hour = selecthour.value;
    var minutes = mlist[hour];
    for (var i = 0; i < 12; i++) {
        opt = minutes[i];
        if (opt != 'hide') {
            var el = document.createElement("option");
            el.textContent = opt;
            el.value = opt;
            selectminute.appendChild(el);
        }
    }
}

function getTime(url, format) {
    $.post(url, $("#make-reservation-modal-form").serialize(), function(data) {
        if (data.success) {
            $("#reservation-hour").empty();
            var selecthour = document.getElementById("reservation-hour");
            var hours = data.hlist;
            mlist = data.mlist;
            var am = 0;
            var pm = 0;
            var hour12 = (format == 12 ? true : false);
            for (var i = 0; i < 24; i++) {
                var opt = hours[i];
                if (opt != 'hide') {
                    if (am == 0 && i < 12 && hour12) {
                        var amgroup = document.createElement('OPTGROUP');
                        amgroup.label = "-am-";
                        selecthour.appendChild(amgroup);
                        am = 1;
                    }

                    if (pm == 0 && i > 11 && hour12) {
                        var pmgroup = document.createElement('OPTGROUP');
                        pmgroup.label = "-pm-";
                        selecthour.appendChild(pmgroup);
                        pm = 1;
                    }

                    var el = document.createElement("option");
                    el.textContent = opt;
                    if (i == 0 && hour12) {
                        el.textContent = 12;
                    } else if (i > 12 && hour12) {
                        el.textContent = i - 12;
                    } else {
                        el.textContent = i;
                    }
                    el.value = i;
                    selecthour.appendChild(el);

                }
            }
            getMinute();
        } else {
            setTime();
        }
    });
}

function formatHour(hourSelect, ampmLabel) {
    var sh = document.getElementById(hourSelect);
    var ampm = document.getElementById(ampmLabel);
    if (sh.value > 11) {
        ampm.textContent = "pm";
    } else {
        ampm.textContent = "am";
    }
}
