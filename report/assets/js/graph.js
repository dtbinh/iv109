function renderGraph(source, wrapper) {
    var intersections = ["roundabout", "roundabout-quick-right", "traffic-lights"];
    var traits = [];
    for(var i = 0; i <= 950; i += 20)
        traits.push(i);

    var m = [80, 160, 200, 40];
    var w = 1200 - m[1] - m[3];
    var h = 720 - m[0] - m[2];

    var x = d3.scale.ordinal().domain(traits).rangePoints([0, w]);
    var y = {};

    var line = d3.svg.line();
    var axis = d3.svg.axis().orient("left");
    var foreground;

    var svg = d3.select(wrapper).append("svg:svg")
        .attr("width", w + m[1] + m[3])
        .attr("height", h + m[0] + m[2])
        .append("svg:g")
        .attr("transform", "translate(" + m[3] + "," + m[0] + ")");

    var rows = d3.csv.parse(source);

    // Create a scale and brush for each trait.
    traits.forEach(function(d) {
        // Coerce values to numbers.
        rows.forEach(function(p) { p[d] = +p[d]; });

        if(d == 'north' || d == 'east' || d == 'south' || d == 'west') {
            y[d] = d3.scale.linear()
                .domain(d3.extent(rows, function(p) { return p[d]; }))
                .range([h, 0]);
        } else {
            y[d] = d3.scale.linear()
                .domain([0, 350])
                .range([h, 0]);
        }

        y[d].brush = d3.svg.brush()
            .y(y[d]);
    });

    // Add a legend.
    var legend = svg.selectAll("g.legend")
        .data(intersections)
        .enter().append("svg:g")
        .attr("class", "legend")
        .attr("transform", function(d, i) { return "translate(0," + (i * 20 + 524) + ")"; });

    legend.append("svg:line")
        .attr("class", String)
        .attr("x2", 8);

    legend.append("svg:text")
        .attr("x", 12)
        .attr("dy", ".31em")
        .text(function(d) { return d; });

    // Add foreground lines.
    foreground = svg.append("svg:g")
        .attr("class", "foreground")
        .selectAll("path")
        .data(rows)
        .enter().append("svg:path")
        .attr("d", path)
        .attr("class", function(d) { return d.intersection + (d.run == $(".slider", wrapper).val() ? "" : " fade"); });

    for(var i = 0; i < rows.length; i++) {
        if(rows[i]['run'] == $(".slider", wrapper).val()) {
            $('.north', wrapper).text(rows[i]['north']);
            $('.east', wrapper).text(rows[i]['east']);
            $('.south', wrapper).text(rows[i]['south']);
            $('.west', wrapper).text(rows[i]['west']);
            break;
        }
    }

    // Add a group element for each trait.
    var g = svg.selectAll(".trait")
        .data(traits)
        .enter().append("svg:g")
        .attr("class", "trait")
        .attr("transform", function(d) { return "translate(" + x(d) + ")"; });

    // Add an axis and title.
    g.append("svg:g")
        .attr("class", "axis")
        .each(function(d) { d3.select(this).call(axis.scale(y[d])); })
        .append("svg:text")
        .attr("text-anchor", "middle")
        .attr("y", -9)
        .text(String);

    // Returns the path for a given data point.
    function path(d) {
        return line(traits.map(function(p) { return [x(p), y[p](d[p])]; }));
    }

    $(".slider", wrapper).change(function(e) {
        foreground.classed("fade", function(d) {
            if(d["run"] == $(".slider", wrapper).val()) {
                $('.north', wrapper).text(d['north']);
                $('.east', wrapper).text(d['east']);
                $('.south', wrapper).text(d['south']);
                $('.west', wrapper).text(d['west']);
            }

            return !["run"].every(function(p) {
                return d[p] == $(".slider", wrapper).val();
            });
        });
    });
};