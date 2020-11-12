function [xAxis, yAxis, inAxes, numericText] = findAxes(fig, resulttextnum_w)
% Identify x and y axes by identifying axis ticks on locations of text
% boxes containing  numbers, returning axis locations, the text boxes
% they consist of, and
% models of scale to convert from pixel coordinates on the fig image to
% data coordinates.
%
% fig is a Figure object.
% xAxis and yAxis are axis objects corresponding to the two axes.
% inAxis is a logical vector of which text boxes from fig are from the
% axes (returned so they can be excluded during legend detection)
% Only look at text that can be parsed as a number
%  isNumeric表示包含数字的textBox用1表示，不是数字为0

nTextBoxes = length(fig.textBoxes);
isNumeric = cellfun(@(tb) ~isnan(str2double(strrep((tb.text),'%',''))) , fig.textBoxes);
isNumeric1 = cellfun(@(tb) ~isnan(str2double(strrep((tb.text),'−',''))) , fig.textBoxes);
for i = 1:length(isNumeric)
    isNumeric(i) = isNumeric(i) || isNumeric1(i);
end


% numericText表示数字box中的内容：box,text,rotation
numericText = [fig.textBoxes{isNumeric}];
% Find the x and y axes by looking for the most numeric text boxes that
% line up horizontally and vertically, respectively.
% Find x axis
maxAlignedBoxes = -1;
% zeros生成全0矩阵，size表示的图片提取是数字box的个数
inXAxis = zeros(size(numericText));
xAxisLocation = -1;
% Check each pixel row
%  size(fig.image,1)返回的是这个图片分为像素之后的行数
%循环从最大值开始，每次减1，直到值为1
for y = size(fig.image,1):-1:1
    % Count the number of numeric text boxes in that row
    inRow = arrayfun(@(tb) (tb.box(2)<=y) & (tb.box(2)+tb.box(4)/2>=y), numericText);
    if sum(inRow)>maxAlignedBoxes
        maxAlignedBoxes = sum(inRow);
        inXAxis = inRow;
        xAxisLocation = y;
    end    
end
%disp(inXAxis)
% Find y axis
maxAlignedBoxes = -1;
inYAxis = zeros(size(numericText));
yAxisLocation = -1;
% Check each pixel column
for x = 1:size(fig.image,2)
    % Count the number of numeric text boxes in that column
    inColumn = arrayfun(@(tb) (tb.box(1)+tb.box(3)/2<=x) & (tb.box(1)+tb.box(3)>x), numericText);
    if sum(inColumn)>maxAlignedBoxes
        maxAlignedBoxes = sum(inColumn);
        inYAxis = inColumn;
        yAxisLocation = x;
    end
end
%disp(inYAxis)

% If any boxes were found for both axes, we're not sure what axis they're
% from, so to be safe, don't use them to determine either scale.
intersection = inXAxis & inYAxis;
xAxisBoxes = numericText(inXAxis & ~intersection);
yAxisBoxes = numericText(inYAxis & ~intersection);
%  numel表示返回给定x轴的像素数
if numel(xAxisBoxes) <= 1
    error('FigureSeer:noAxis', 'No numeric x-axis found');
end
if numel(yAxisBoxes) <= 1
    error('FigureSeer:noAxis', 'No numeric y-axis found');
end

% Fit linear and logarithmic models on both axes to determine best fit.
xTickPositions = arrayfun(@(tb) tb.box(1)+tb.box(3)/2, xAxisBoxes);
yPositions = arrayfun(@(tb) tb.box(2)+tb.box(4)/2, xAxisBoxes); %计算x轴的文本所处的那条线得y值
xTickValues = arrayfun(@(tb) (str2double(strrep((tb.text),'%',''))), xAxisBoxes);
for i = 1:length(xAxisBoxes)
    if strfind(xAxisBoxes(i).text,'−')
        xTickValues(i) = str2double(strrep((xAxisBoxes(i).text),'−','')) * (-1);
    end
end
%disp(xTickValues)
[xTickPositions,xOrder] = sort(xTickPositions,'ascend');
xTickValues = xTickValues(xOrder);
x_distance = xTickValues(3) - xTickValues(2); %x轴间隔
if ~(all(diff(xTickValues)>0) || all(diff(xTickValues)<0))
    error('FigureSeer:axisNotMonotonic','X axis not monotonic');
end
[xModel, xType] = fitAxisModel(xTickPositions, xTickValues);

yTickPositions = arrayfun(@(tb) tb.box(2)+tb.box(4)/2, yAxisBoxes);
xPositions = arrayfun(@(tb) tb.box(1)+tb.box(3)/2, yAxisBoxes);%y轴上的x值
yTickValues = arrayfun(@(tb) (str2double(strrep((tb.text),'%',''))), yAxisBoxes);
for i = 1:length(yAxisBoxes)
    if strfind(yAxisBoxes(i).text,'−')
        yTickValues(i) = str2double(strrep((yAxisBoxes(i).text),'−','')) * (-1);
    end
end

%disp(yTickValues)
[yTickPositions, yOrder] = sort(yTickPositions,'ascend');
yTickValues = yTickValues(yOrder);
y_distance = yTickValues(2) - yTickValues(3); %y轴间隔
if ~(all(diff(yTickValues)>0) || all(diff(yTickValues)<0))
	error('FigureSeer:axisNotMonotonic','Y axis not monotonic');
end
[yModel, yType] = fitAxisModel(yTickPositions, yTickValues);
%disp(all(xTickValues))
% 检查矩阵中是否全为非零，如果是返回1

% Find Axis Titles

numericIndices = find(isNumeric);
inAxes = zeros(size(fig.textBoxes));
inAxes(numericIndices(inYAxis | inXAxis)) = 1;
nonAxisTextBoxes = [fig.textBoxes{~inAxes}];

% Find text boxes that lie entirely below the x axis
topBound = arrayfun(@(tb) (tb.box(2)), nonAxisTextBoxes);
%disp(topBound)
belowAxis = find(topBound > xAxisLocation);
% If there are any, we use the highest one as the axis label
if isempty(belowAxis)
    xTitle = '';
else
    [~,highest] = min(topBound(belowAxis));
    idx = belowAxis(highest);
    xTitle = nonAxisTextBoxes(idx);
end


% Find text boxes completely to the left of the y axis
rightBound = arrayfun(@(tb) (tb.box(1)+tb.box(3)), nonAxisTextBoxes);
leftOfAxis = find(rightBound < yAxisLocation);
% If there are any, we use the rightmost one as axis label
if isempty(leftOfAxis)
    yTitle = '';
else
    [~,rightmost] = max(rightBound(leftOfAxis));
    idx = leftOfAxis(rightmost);
    yTitle = nonAxisTextBoxes(idx);
end
xAxis = Axis(xAxisLocation, min(xTickValues), max(xTickValues), x_distance, xModel, xType, xTitle, numericIndices(inXAxis));
yAxis = Axis(yAxisLocation, min(yTickValues), max(yTickValues), y_distance, yModel, yType, yTitle, numericIndices(inYAxis));

if min(xTickValues)~=0 & min(xTickValues)-x_distance == 0
    xAxis = Axis(xAxisLocation, 0, max(xTickValues), x_distance, xModel, xType, xTitle, numericIndices(inXAxis));
end

if min(yTickValues)~=0 & min(yTickValues)-y_distance == 0
    yAxis = Axis(yAxisLocation, min(yTickValues), max(yTickValues), y_distance, yModel, yType, yTitle, numericIndices(inYAxis));
end


for i = 1:nTextBoxes  %将去掉百分号的数值还原即加上百分号并添加进轴信息中
    textbox = fig.textBoxes{i};
    if strfind(textbox.text,'%')
        if textbox.box(2) + textbox.box(4)/2 == yPositions(1)
            xAxis = Axis(xAxisLocation, [num2str(min(xTickValues)),'%'], [num2str(max(xTickValues)),'%'], [num2str(x_distance),'%'], xModel, xType, xTitle, numericIndices(inXAxis));
        end
        if textbox.box(1) + textbox.box(3)/2 == xPositions(1)
            disp(textbox.box(1) + textbox.box(3)/2)
            disp(textbox.text)
            yAxis = Axis(yAxisLocation, [num2str(min(yTickValues)),'%'], [num2str(max(yTickValues)),'%'], [num2str(y_distance),'%'], yModel, yType, yTitle, numericIndices(inYAxis));
        end
        break    
    end
end



end

function [model, type] = fitAxisModel(coords, values)
% Fit a model mapping pixel coordinates to data coordinates based on axis
% scale.

% Fit linear and logarithmic models on both axes to determine best fit.
rmse = @(mdl) sqrt(mean((mdl.Residuals.Raw).^2));

% Linear model
models{1}.type = 'linear';
models{1}.model = GeneralizedLinearModel.fit(coords, values, 'Link', 'identity');
models{1}.rmse = rmse(models{1}.model);

% Logarithmic model
models{2}.type = 'log';
models{2}.model = GeneralizedLinearModel.fit(coords, values, 'Link', 'log');
models{2}.rmse = rmse(models{2}.model);

% Pick best model based on RMSE
errors = cellfun(@(c) c.rmse,models);
[~,best] = min(errors);
model = models{best}.model;
type = models{best}.type;
end