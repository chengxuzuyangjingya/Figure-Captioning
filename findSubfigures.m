function subfigures = findSubfigures(fig)
grayscaleImage = rgb2gray(fig.image);
subfigureBoxes = recursiveSplit(grayscaleImage, 0, 0);


if length(subfigureBoxes) == 1
    subfigures = fig;
else
    subfigures(1, length(subfigureBoxes)) = Figure();
    for n = 1:length(subfigureBoxes)
%这个box是分成的子图整体的坐标，如分成三个子图就有三个box,[x,y,w,h]
        box = subfigureBoxes{n};
        shiftedBoxes = cellfun(@(tb) shiftOrCropTextbox(tb, box), fig.textBoxes, 'UniformOutput', false);
        
        subfigTextBoxes = shiftedBoxes(~cellfun(@isempty, shiftedBoxes));
        subfigImage = imcrop(fig.image, box);
        subfigures(n) = Figure(subfigImage, subfigTextBoxes);
    end
end

%下面这一段画的结果图在subfigure-vis文件夹中

% Produce visualization
figure(1),clf;
% figure(1),imshow(fig.image);
imsize = size(fig.image);
% rectangle表示绘制图，中括号对应[x,y,w,h],用黑色画
rectangle('Position',[1,1,imsize(2)-1,imsize(1)-1],'EdgeColor','black','LineWidth',2);
% subfigureBoxes表示的是大图可以分成子图的个数
for n = 1:length(subfigureBoxes)
    rectangle('Position',subfigureBoxes{n},'EdgeColor','red','LineWidth',2);
end
end
    
function newTextBox = shiftOrCropTextbox(textBox, subfigBox)
% If the text box is inside the subfigure, change its coordinates
% from full figure to subfigure. If not, remove it.

%下面的if相当于循环，textbox是整个大图的textbox，然后与子图的整体box进行坐标的转换

if isInside(textBox.box, subfigBox)
    box = textBox.box - [subfigBox(1)-1, subfigBox(2)-1, 1, 1];
    box(1) = max([box(1), 1]);
    box(2) = max([box(2), 1]);
    box(3) = min([box(3), subfigBox(3) - box(1) + 1]);
   
    box(4) = min([box(4), subfigBox(4) - box(2) + 1]);
    newTextBox = textBox;
    newTextBox.box = box;
    
else
    newTextBox = [];
end
end

function result = isInside(a,b)
SLACK = 4;
a = whToBounds(a);
b = whToBounds(b);
distanceOutOfBounds = max([b(1)-a(1),b(2)-a(2),a(3)-b(3),a(4)-b(4)]);
result = distanceOutOfBounds <= SLACK;
end

function subfigureBoxes = recursiveSplit(im, leftOffset, topOffset)
% Given a subfigure, split it into two subfigures if possible, then
% recursively call on each.
%
% im is a grayscale uint8 image.
% leftOffset and topOffset are the offsets to translate coordinates on im
% to coordinates in the full figure.

MINIMUM_PIXEL_WIDTH = 100; % Minimum size of any subfigure
MAX_ASPECT_RATIO = 5; % Maximum allowed aspect ratio of any subfigure
MAX_WIDTH_RATIO = 2.5; % Maximum allowed ratio of widths between two subfigures being split

% Crop off whitespace from the edges
nonwhiteCols = find(sum(255-im,1));
leftNonwhite = nonwhiteCols(1);
rightNonwhite = nonwhiteCols(end);
nonwhiteRows = find(sum(255-im,2));
topNonwhite = nonwhiteRows(1);
botNonwhite = nonwhiteRows(end);
im = imcrop(im, [leftNonwhite, topNonwhite, rightNonwhite-leftNonwhite, botNonwhite-topNonwhite]);
newLeftOffset = leftOffset+leftNonwhite-1;
newTopOffset = topOffset+topNonwhite-1;

% Find columns of entirely white space
v = sum(255-im,1)==0;
v = v(:);
s = sprintf('%d',v);
t = textscan(s,'%s','delimiter','0','multipleDelimsAsOne',1);
columnWidths = cellfun(@length,t{1});
dv = diff(v);
columnStarts = find(dv==1);
% Find rows of entirely white space
v = sum(255-im,2)==0;
v = v(:);
s = sprintf('%d',v);
t = textscan(s,'%s','delimiter','0','multipleDelimsAsOne',1);
rowWidths = cellfun(@length,t{1});
dv = diff(v);
rowStarts = find(dv==1);

allRuns = [rowWidths; columnWidths];
runDims = [2*ones(size(rowWidths)); 1*ones(size(columnWidths))];
runPos = [rowStarts;columnStarts]+1;
[~,order] = sort(allRuns,'descend');

% In order of width, check each row/column to see if it is a valid split
for n = 1:length(allRuns)
    runDim = runDims(order(n));
    if runDim == 1
        % Column
        whiteCol = runPos(order(n));
        leftim = im(:,1:whiteCol);
        rightim = im(:,whiteCol:end);
        imA = leftim;
        leftOffA = newLeftOffset;
        topOffA = newTopOffset;
        imB = rightim;
        leftOffB = newLeftOffset+whiteCol-1;
        topOffB = newTopOffset;
        widthRatio = abs(log(size(imA,2)/size(imB,2)));
    else
        % Row
        whiteRow = runPos(order(n));
        topim = im(1:whiteRow,:);
        botim = im(whiteRow:end,:);
        imA = topim;
        leftOffA = newLeftOffset;
        topOffA = newTopOffset;
        imB = botim;
        leftOffB = newLeftOffset;
        topOffB = newTopOffset+whiteRow-1;
        widthRatio = abs(log(size(imA,1)/size(imB,1)));
    end
    if max(abs([log(size(imA,1)/size(imA,2)),log(size(imB,1)/size(imB,2))])) > log(5)
        continue
    elseif widthRatio > log(MAX_WIDTH_RATIO)
        continue
    elseif min([size(imA), size(imB)]) < MINIMUM_PIXEL_WIDTH
        continue
    end
    % Recursive case
    subfigureBoxes = [recursiveSplit(imA,leftOffA,topOffA), recursiveSplit(imB,leftOffB,topOffB)];
    return;
end

% Base case, no split found
subfigureBoxes = {[newLeftOffset, newTopOffset, size(im,2)-1, size(im,1)-1]};
end