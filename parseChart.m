function [results, figure_first, figure_second, givelegends, giveimage, resulttextnum_w, cutnum_w] = parseChart(fig, figureName, figure_first, figure_second, givelegends, giveimage, resulttextnum_w, cutnum_w, conf)
% Check if we have text
if isempty(fig.textBoxes)
    results.error = 'No text detected';
    return;
end
% Find image axes and axis labels
textname1 = '/home/d2zhang/wutlab/figureseer/data/output/text_result.txt';
fid1 = fopen(textname1,'w');
resulttextnum_w = resulttextnum_w + 1;
fprintf(fid1,'%d\n',resulttextnum_w);
try
    [xAxis, yAxis] = findAxes(fig, resulttextnum_w);
catch
    nTextBoxes = length(fig.textBoxes);
    isNumeric = cellfun(@(tb) ~isnan(str2double(strrep((tb.text),'%',''))) , fig.textBoxes);
    isNumeric1 = cellfun(@(tb) ~isnan(str2double(strrep((tb.text),'−',''))) , fig.textBoxes);
    for i = 1:length(isNumeric)
        isNumeric(i) = isNumeric(i) || isNumeric1(i);
    end
    numericText = [fig.textBoxes{isNumeric}];
    if length(numericText) < 5
        results.error = 'Failes to parse figure information';
        textname4 = '/home/d2zhang/wutlab/figureseer/data/output/cutnum.txt';
        fid4 = fopen(textname4,'w');
        cutnum_w = cutnum_w + 1;
        fprintf(fid4,'%d\n',cutnum_w);
        return
    else
        results.error = 'Failed to find two numeric axes';
        return;
    end
end

% Legend classification and symbol detection
try
    [legendEntries, cleanedFigureImage] = findLegend(fig, xAxis.textBoxIndices, yAxis.textBoxIndices, conf.legendClassifier);
catch
    results.error = 'Failed to find legend';
    return;
end
S = regexp(figureName,'-','split');
%imwrite(cleanedFigureImage,fullfile('~/wutlab/figureseer/data/pngs/png2/png3',[S{1} S{2} S{3} '.png']))
%if exist(figure_first)
%    disp('hhhh')
%end
if isempty(legendEntries)
    if isequal(S{2}, figure_second) && isequal(S{1}, figure_first)
        legendEntries = givelegends;
    else
        
        results.error = 'Failed to find legend';
        return;  
    end 
else
    figure_first = S{1};
    figure_second = S{2};
    givelegends = legendEntries;
end
originalImage = fig.image;
fig.image = cleanedFigureImage;
% Crop plot area
try
    [croppedImage, cropBounds] = cropPlotArea(fig, xAxis, yAxis);
catch
    results.error = 'Failed to plot area';
    return; 
end
% Generate featuremaps, compute weighted sum, solve dynamic program
try
    traces = traceData(croppedImage, legendEntries, cropBounds(2), cropBounds(1), conf); 
catch
    results.error = 'Failed to trace';
    return;
end

for n = 1:length(traces)
    traces(n).xs = xAxis.model.predict(traces(n).pixelXs);
    traces(n).ys = yAxis.model.predict(traces(n).pixelYs);
end


% Plot results
fontSize = 20;
f = figure(1);
clf;
set(f, 'Position', [1 1 1000 400]);
subplot(1,2,1);
%imshow(originalImage);
title('Original')
set(gca, 'fontsize', fontSize);

subplot(1,2,2);
hold on;

if strfind(xAxis.min,'%')
    xMinBound = str2double(strrep(xAxis.min,'%','')); 
else
    xMinBound = xAxis.min;
end
if strfind(xAxis.max,'%')
    xMaxBound = str2double(strrep(xAxis.max,'%',''));
else
    xMaxBound = xAxis.max;
end

if strfind(yAxis.min,'%')
    yMinBound = str2double(strrep(yAxis.min,'%',''));
else
    yMinBound = yAxis.min;
end

if strfind(yAxis.max,'%')
    yMaxBound = str2double(strrep(yAxis.max,'%',''));
else
    yMaxBound = yAxis.max;
end

% Use linear or logarithmic axes
xIsLog = strcmp(xAxis.modelType, 'log');
yIsLog = strcmp(yAxis.modelType, 'log');
if xIsLog && yIsLog
    plotWithAxes = @loglog;
elseif xIsLog
    plotWithAxes = @semilogx;
elseif yIsLog
    plotWithAxes = @semilogy;
else
    plotWithAxes = @plot;
end
for trace = traces
    xs = xAxis.model.predict(trace.pixelXs);
    ys = yAxis.model.predict(trace.pixelYs);
    plotWithAxes(xs, ys, 'LineWidth', 5);
    % Someones we miss the true min or max tick, so set bounds that don't cut off any points
    xMinBound = min([xMinBound; xs(:)]);
    xMaxBound = max([xMaxBound; xs(:)]);
    yMinBound = min([yMinBound; ys(:)]);
    yMaxBound = max([yMaxBound; ys(:)]);
end

axis([xMinBound xMaxBound yMinBound yMaxBound]);


if isempty(xAxis.title)
    xlabel('')
else
    xlabel(xAxis.title.text)
end
% xlabel 为gca命令返回的当前坐标区或图的x轴添加标签,ylabel则是为y轴添加标签
if isempty(yAxis.title)
    ylabel('')
else
    ylabel(yAxis.title.text)
end
legendLabels = arrayfun(@(l) l.label, legendEntries, 'UniformOutput', false);
legend(legendLabels);
title('Reproduced');
set(gca, 'fontsize', fontSize);

results.xAxis = xAxis;
results.yAxis = yAxis;
results.legendEntries = legendEntries;
results.traces = traces;