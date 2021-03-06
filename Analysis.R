```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
require("knitr")
```

## Index:
1. Analytics:
- The dataset, some plots
2. Feature extraction and selection
- Day, exclusion of Humidity Ratio, time-dependent variations
3. Models
- Logistic Regression
- Linear Discriminant Analysis
- Quadratic Discriminant Analysis
- K-Nearest Neighbours
- Support Vector Classifier
- Classification tree
- Random Forestz
4. Light exclusion
5. How many people in the room?
6. Conclusions

Let us load our data. We are provided with three datasets: one training set and two test tests. Since the two test sets have the same columns, we simply merge them together.


```{r}
train <- read.csv("datatraining.txt", header=T)
test <- rbind(read.csv("datatest.txt", header=T), read.csv("datatest2.txt", header=T))
```

Let us inspect the dataset, by looking at the variables.

```{r}
summary(train)
dim(train)
summary(test)
dim(test)
```

As can be seen above, the training set is made of 8143 rows and 7 columns. The variables provide information about humidity, temperature, light and CO2 level of a room through time, as well as about the presence of people, which is expressed in a binary form (either the room is empty or it is not). Our aim is to predict whether there is someone in the room or not based on these features. We will buildd some models and test them on the test set, which is made of 12417 rows and the same columns.

Some plots:

```{r}
library(tidyverse)
library(cowplot)

train$Occupancy <- as.factor(train$Occupancy)

BARone <- ggplot(train, aes(Occupancy, Temperature, fill=Occupancy))+
  stat_summary(fun.y = mean,
               geom = 'bar',
               position = 'dodge') + scale_fill_manual(values = c('pink', 'grey'))+
  theme(legend.position="none")

BARtwo <- ggplot(train, aes(Occupancy, Humidity, fill=Occupancy))+
  stat_summary(fun.y = mean,
               geom = 'bar',
               position = 'dodge')+
    theme(legend.position="none")

BARthree <- ggplot(train, aes(Occupancy, Light, fill=Occupancy))+
  stat_summary(fun.y = mean,
               geom = 'bar',
               position = 'dodge')+
    theme(legend.position="none")

BARfour <- ggplot(train, aes(Occupancy, CO2, fill=Occupancy))+
  stat_summary(fun.y = mean,
               geom = 'bar',
               position = 'dodge')+
    theme(legend.position="none")

plot_grid(BARone, BARtwo, BARthree, BARfour, labels = "AUTO")
```

### New columns

First of all we notice that there are two measures for the humidity in the room: the humidity and the humidity ratio. By looking at the attribute information of the dataset we find out that the humidity ratio is a quantity derived directly from temperature and relative humidity. Since those two variables are both contained in the dataset, we might incur in collinearity if we created models including all the three variables. This guess is confirmed by the following:

```{r}
summary(lm(HumidityRatio ~ Temperature + Humidity, data=train))$adj.r.squared
```

Humidity ratio is explained completely by the two variables: we will exclude it in the models to not incur in collinearity.
Before building models, we want to expand our dataset, by taking advantage of the time order of our datapoints.
The first thing we could do is to verify where each observation is recorded during daytime or not.
First of all, we transform the variable date from a factor into a temporal one.

```{r}
library(lubridate)
Hour <- c()
train$date <- as.POSIXct(train$date, format="%Y-%m-%d %H:%M:%S")
for (i in 1:dim(train)[1]){
  H <- hour(train$date[i])
  Hour <- append(Hour, H)
}
HourT <- c()
for (i in 1:dim(test)[1]){
  H <- hour(test$date[i])
  HourT <- append(HourT, H)
}
Hour <- as.numeric(Hour)
HourT <- as.numeric(HourT)
Day <- c()
for (i in 1:dim(train)[1]){
  ifelse(between(Hour[i], 8, 20), Day <- append(Day, TRUE), Day <- append(Day, FALSE))
}
DayT <- c()
for (i in 1:dim(test)[1]){
  ifelse(between(HourT[i], 8, 20), DayT <- append(DayT, TRUE), DayT <- append(DayT, FALSE))
}
train$Day <- Day
test$Day <- DayT
```

```{r}
ggplot(data = train, aes(x = date, y = as.factor(Occupancy), color=Day)) +
         geom_point() +
         scale_color_manual(values=c('black', 'cyan')) +
         ylab('Occupancy')
         
```

Also, it may be interesting to investigate whether the change in some of the conditions in the room through time is a good predictor of human presence. This is because the original features, as provided in the dataset, express an absolute value of the room temperature, humidity and so on, which in turn can be affected by other variables (such as the time of the day, the season or the general external climate conditions). On the other hand, the increase in temperature, humidity, CO2 concentration and light level may be determined by the presence of people. We choose to calculate how these conditions change in 1 minute, by subtracting each row with the previous one. 

```{r}
len <- dim(train)[1]

train$hum_change <- rep(0, len)
train$temp_change <- rep(0, len)
train$CO2_change <- rep(0, len)
train$light_change <- rep(0, len)

for(i in 2:len){
  train$hum_change[i] = train$Humidity[i] - train$Humidity[i-1]
  train$temp_change[i] <- train$Temperature[i] - train$Temperature[i-1]
  train$CO2_change[i] <- train$CO2[i] - train$CO2[i-1]
  train$light_change[i] <- train$Light[i] - train$Light[i-1]
}
```

## Models

### Logistic regression

With original data
```{r}
glm_mod <- glm(Occupancy ~ Temperature+ Humidity+ Light+ CO2+ HumidityRatio, family="binomial", data=train)
summary(glm_mod)
```

Adding the new cols
```{r}
glm_mod_exp <- glm(Occupancy ~. - date, family="binomial", data=train)
summary(glm_mod_exp)
```

Removing HumidityRatio and some of the new cols from the model.

```{r}
glm_mod_exp <- glm(Occupancy ~ Temperature + Humidity + Light + CO2 + hum_change + light_change, family="binomial", data=train)
summary(glm_mod_exp)
```
All the predictors are significant but the change in temperature and in CO2 concentration. The AIC gets lower, which means that the model is less complex but still a good fit for the data.

Now, we want to test the model on the test set. To do so, we need do add the columns as we have done above.

```{r}
len <- dim(test)[1]

test$hum_change <- rep(0, len)
test$temp_change <- rep(0, len)
test$CO2_change <- rep(0, len)
test$light_change <- rep(0, len)

for(i in 2:len){
  test$hum_change[i] = test$Humidity[i] - test$Humidity[i-1]
  test$temp_change[i] <- test$Temperature[i] - test$Temperature[i-1]
  test$CO2_change[i] <- test$CO2[i] - test$CO2[i-1]
  test$light_change[i] <- test$Light[i] - test$Light[i-1]
}
```

Creation of a variable Daytime.

```{r}
Hour <- c()
for (i in 1:dim(train)[1]){
  date = as.POSIXct(toString(train$date[i]))
  Hour <- append(Hour,strftime(date, format(date, format="%H")))
}
HourT <- c()
for (i in 1:dim(test)[1]){
  date = as.POSIXct(toString(test$date[i]))
  HourT <- append(HourT,strftime(date, format(date, format="%H")))
}
Hour <- as.numeric(Hour)
HourT <- as.numeric(HourT)
Day <- c()
for (i in 1:dim(train)[1]){
  ifelse(between(Hour[i], 8, 20), Day <- append(Day, TRUE), Day <- append(Day, FALSE))
}
DayT <- c()
for (i in 1:dim(test)[1]){
  ifelse(between(HourT[i], 8, 20), DayT <- append(DayT, TRUE), DayT <- append(DayT, FALSE))
}
train$Day <- Day
test$Day <- DayT
```

Now, we can make predictions. 

```{r}
test.probs <- predict(glm_mod_exp, test, type = 'response')
test.pred <- rep(0, nrow(test))
test.pred[test.probs >= 0.5] <- 1
table(predict=test.pred, truth=test$Occupancy)
```

```{r}
glm_mod_expo <- glm(Occupancy ~ Temperature + Humidity + Light + CO2 + hum_change + light_change + Day, family="binomial", data=train)
test.probs <- predict(glm_mod_expo, test, type = 'response')
test.pred <- rep(0, nrow(test))
test.pred[test.probs >= 0.5] <- 1
table(predict=test.pred, truth=test$Occupancy)
```

We expect the last model, with the new columns, to work better than the one with only the original features. Let's see if that is true.

```{r}
test.probs <- predict(glm_mod, test, type = 'response')
test.pred <- rep(0, nrow(test))
test.pred[test.probs >= 0.5] <- 1
table(predict=test.pred, truth=test$Occupancy)
```
 
Yes, it is. 


### Linear Discriminant Analysis

Let us perform a linear discriminant analysis on our data, by including the same variables that we considered in the glm.

```{r}
library(MASS)
lda.room <- lda(Occupancy ~ Temperature + Humidity + Light + CO2 + hum_change + light_change, data=train)
lda.predictions <- predict(lda.room, newdata = test)
table(predict=lda.predictions$class, truth=test$Occupancy)
mean(lda.predictions$class == test$Occupancy)
```

The accuracy improves considerably. On the other hand, including the variable "Day" as well does not determine a significant change (only 2 mistakes less).

### Quadratic Discriminant Analysis

Same principle as LDA but with some additional flexibility. The model behaves not as well as before.

```{r}
qda.room <- qda(Occupancy ~ Temperature + Humidity + Light + CO2 + Day + hum_change + light_change, data=train)
qda.predictions <- predict(qda.room, newdata=test)
table(predict=qda.predictions$class, truth=test$Occupancy)
mean(qda.predictions$class == test$Occupancy)
```

Let's roc

```{r}
library(pROC)
par(pty='s')
roc(test$Occupancy, as.numeric(lda.predictions$class), plot=T, percent=T, legacy.axes=T, xlab='False Positive Percentage', ylab='True Positive Percentage', col='blue', print.auc=T)
roc(test$Occupancy, as.numeric(qda.predictions$class), plot=T, percent=T, legacy.axes=T, xlab='False Positive Percentage', ylab='True Positive Percentage', col='red', print.auc=T, print.auc.y=40, add=T)
legend('bottomright', legend=c('LDA', 'QDA'), col = c('blue', 'red', 'green'), lwd=4)
```

### KNN

```{r}
library(class)
set.seed(78)
knn.pred <- knn(train[c(2,3,4,5,8,9,12)], test[c(2,3,4,5,8,9,12)], train$Occupancy, k=1)
table(predict=knn.pred, truth=test$Occupancy)
mean(knn.pred == test$Occupancy)
```

### Tree

Now we want to build a classification tree on our dataset.

```{r}
library(tree)
library(rpart)
library(rpart.plot)

#Using function tree
tree.room <- tree(Occupancy~ Temperature + Humidity + Light + CO2 + hum_change + light_change, train)
plot(tree.room)
text(tree.room, pretty=0)

#Using function rpart
tree.room.rpart <- rpart(Occupancy~Temperature + Humidity + Light + CO2 + hum_change + light_change, data=train)
```

Now let us test it on the test set.

```{r}
yhat.room <- predict(tree.room, test, type="class")
#to compute the error
table(predict=yhat.room, truth=test$Occupancy)
mean(yhat.room==test$Occupancy)
```

Bagging

```{r}
library(randomForest)
bag.room <- randomForest(Occupancy~ Temperature + Humidity + Light + CO2 + hum_change + light_change, data=train, mtry=5)
bag.room
bag.room$importance
varImpPlot(bag.room)

#Predictions
yhat.bag <- predict(bag.room, test)
table(predict=yhat.bag, truth=test$Occupancy)
mean(yhat.bag==test$Occupancy)
```

Looking at the importance of the variables, we can clearly notice that light is the most important one. Also, by performing bagging, the model accuracy increases considerably.
(OOB estimate of  error rate: 0.64%)

Accuratezza bagging ->95%.

## Random forest

We want to build different random forests with default parameters. We do not include the variables that were not significant in the previous models, as we do not expect them to improve the accuracy of the forests and to reduce computational costs.
```{r}
library(randomForest)
set.seed(1)
forests_default <- data.frame(matrix(, nrow=, ncol=2))
names(forests_default) <- c("m", "Accuracy")
for(m in 1:6){
  rf.room <- randomForest(Occupancy~ Temperature+ Humidity + Light + CO2 + hum_change + light_change, data=train ,mtry=m)
  yhat.rf <- predict(rf.room, newdata=test)
  forests_default[m,] <- c(m, mean(yhat.rf==test$Occupancy))
}
forests_default

ggplot(forests_default, aes(forests_default$m, forests_default$Accuracy)) + geom_line() + geom_point() + xlab("Number of features") + ylab("Accuracy")

```
We can see that:
1) the most accurate forest is less accurate than the single classification tree;
2) the more variables are included, the less accurate is the model. 


Let us play with the other parameters to see how things change. More specifically, we want to modify the number of trees used to build the forest ("ntree") and the size of the sample that is extracted from the train set ("sampsize"). 

### Number of trees 

Generally, increasing the number of trees leads to an increase in accuracy. However, in this case the improvement is not relevant, so we keep the number of trees as default. 
```{r}
set.seed(1)
forests <- data.frame(matrix(, nrow=, ncol=2))
names(forests) <- c("m", "Accuracy")
for(m in 1:6){
  rf.room <- randomForest(Occupancy~ Temperature+ Humidity + Light + CO2 + hum_change + light_change, data=train ,mtry=m, ntree=600)
  yhat.rf <- predict(rf.room, newdata=test)
  forests[m,] <- c(m, mean(yhat.rf==test$Occupancy))
}
forests
```
### Sample size

What about the portion of the data that is extracted from the train set to build the forests? If we keep the sample size as default, the whole train set will be used. However, the train set is slightly biased towards the 0 class, as about 20% of the records are labelled with 0 (empty room). We want to try to downsample a bit the majority class, in favour of the class 1 (occupied room). By doing so, we expect to increase the accuracy, and in particular to reduce the number of false negatives. We prefer to improve the sensitivity  over the specificity as we do not want our model to predict the room as empty just because it happens to be empty more frequently (false negatives). 

```{r}
set.seed(1)
forests <- data.frame(matrix(, nrow=, ncol=2))
names(forests) <- c("m", "Accuracy")
for(m in 1:6){
  rf.room <- randomForest(Occupancy~ Temperature+ Humidity + Light + CO2 + hum_change + light_change, data=train ,mtry=m, sampsize=c(400,700), strata=train$Occupancy)
  yhat.rf <- predict(rf.room, newdata=test)
  forests[m,] <- c(m, mean(yhat.rf==test$Occupancy))
}
forests
```
As a consequence, more parameters are needed: to tell if a room is empty, it is sufficient to know the level of light in the room, but to be sure that someone is in there we need more details. (HA SENSO?). We can summarize these results by looking at this plot:

```{r}
theme_set(theme_bw())
ggplot() + 
  geom_line(data=forests_default, aes(x =m, y=Accuracy, color ="sample size = 8132")) + 
  geom_line(data=forests, aes(x=m, y=Accuracy, color = "sample size=c(400,700)"))+ 
  geom_point(data=forests_default, aes(x =m, y=Accuracy)) + 
  geom_point(data=forests, aes(x=m, y=Accuracy))+
  scale_x_continuous(breaks = seq(1, 6, by = 1))+
  labs(x="",
      y="",
      color = "Legend")
  
```
Let us plot the ROC curves too. In particular, we want to compare the AUC of the most accurate forest with the default sample size (which is the one with mtry=1), with the AUC of the most accurate forest with the downsampled size (which is the one with mtry=4)  

```{r}
library(pROC)

rf1 <- randomForest(Occupancy~ Light+ Humidity  + CO2 + Temperature+ hum_change + light_change, data=train ,mtry=1)
yhat1 <- predict(rf1, newdata=test)

rf2 <- randomForest(Occupancy~ Light+ Humidity  + CO2 + Temperature+ hum_change + light_change, data=train ,mtry=4, sampsize=c(400,600))
yhat2 <- predict(rf2, newdata=test)

par(pty='s')
roc(test$Occupancy, as.numeric(yhat1), plot=T, percent=T, legacy.axes=T, xlab='False Positive Percentage', ylab='True Positive Percentage', col='blue', print.auc=T)
roc(test$Occupancy, as.numeric(yhat2), plot=T, percent=T, legacy.axes=T, xlab='False Positive Percentage', ylab='True Positive Percentage', col='red', print.auc=T, print.auc.y=40, add=T)
legend('bottomright', legend=c('Default', 'Downsampling'), col = c('blue', 'red'), lwd=4)

```

Boosting

```{r}
library(adabag)
boost <- boosting(Occupancy~Temperature + Humidity + Light + CO2 + hum_change + light_change, data=train)
boost <- predict(A, newdata=test)
boost$error
```

A possible explanation for random forests being less accurate than a single classification tree when tested on the test set has to be found in the algorithm behind the construction of random forestes itself.
A random forest is built using m features which are randomly picked, in order to obtain trees that are not correlated between each others and improve the variance.
In our case, when m=1, i.e. when the trees are built using only 1 feature, this procedure might diminish the influence of the variable "Light" (which is able to predict the occupancy on its own, according to the single classification tree), as there will be trees.

### Support Vector Classifier
We look for the hyperplane that best approximates a linear split of our data. The natural choice is the maximal margin hyperplane, which is the separating hyperplane that is farthest from the training observations, if it exists. The parameter cost of the function svm in R controls for the amount of flexibility of our model: initially we look for few violations of the principle of linear separation, we want a margin that is as accurate as possible on the training data. Hence, we want to fit our data hard indicating a high cost for each of those violations.

```{r}
library(e1071)
svc.fun <- svm(Occupancy ~ Temperature + Humidity + Light + CO2 + Day + hum_change + light_change, train, kernel='linear', cost=100, scale=T)
summary(svc.fun)
```

The only observations that do affect the support vector classifier are those that lie directly on the margin or on the wrong side of it. In our first attempt we have 314 support vectors.

```{r}
svc.pred <- predict(svc.fun, test)
table(predict=svc.pred, truth=test$Occupancy)
mean(svc.pred == test$Occupancy)
```

Even though with such a high cost parameter the model is going to behave very well on the training data, this does not necessarily imply the best behavior on test data. Even though there are few prediction errors when we validate our model, it is quite likely that we can improve the performance further by allowing for more violations. We make our model less sensible to the training data by enlarging the margin of the classifier. For choosing the best cost parameter the simplest way is the one of comparing the performance on the validation set.

```{r}
SVCs <- data.frame(matrix(, nrow=, ncol=2))
names(SVCs) <- c("cost", "Accuracy")
counter = 1
for (i in c(50, 10, 5, 1, 0.1, 0.01, 0.001)){
  svc.fun <- svm(Occupancy ~ Temperature + Humidity + Light + CO2 + Day + hum_change + light_change, train, kernel='linear', cost=i, scale=T)
  svc.pred <- predict(svc.fun, test)
  SVCs[counter,] <- c(i, mean(svc.pred == test$Occupancy))
  counter = counter + 1
}
SVCs
```

The cost parameter that results in the best classifier is 1: decreasing cost further makes our margin too wide and increases the number of resulting violations too much. In the bias-variance tradeoff we start with high variance but low bias when we have a high cost parameter and a consequent narrow margin. For this reason we start decreasing the cost value. However, after an equilibrium at around 1 the margin starts becoming too wide: the number of support vectors is becoming too large and we are going towards a situation of high bias. In fact, we are fitting our data less hard and at a certain point (for cost = 1),the amount of rigidity of the system is such that the performance starts decreasing.

```{r}
svc.fun <- svm(Occupancy ~ Temperature + Humidity + Light + CO2 + Day + hum_change + light_change, train, kernel='linear', cost=1, scale=T)
library(ggfortify)
train$Prediction <- svc.fun$fitted
p <- as.factor(svc.pred)
autoplot(prcomp(train[c(2,3,4,5,8,9,10,12)], scale=T), data=train, colour='Prediction', frame=T)
train <- subset(train, select=-13)
```

Ideally, if we were able to visualize data in a multi-dimensional way, we would have the chance of gaze at a classification with only 324 vectors (4% of the observations) lying on it. Since unfortunately this is not the case, we will settle for a bidimensional visualization made possible by a principal component analysis algorithm. Of course much of the accuracy is lost and the two classes are not as splitted as they would be in a multi-dimensional visualization.

### Excluding light

We have now seen how it is relatively to make the right call when making use of the variable light: one could easily argue that it is too trivial to predict the occupancy of a room if the light is turned on. What if, however we were not able to measure light and hence we could not control for it? How much would our model worsen its performance? Let us start from analyzing the behaviour using the logistic function.

```{r}
noLight.log <- glm(Occupancy ~ Temperature + Humidity + CO2 + Day + temp_change + hum_change + CO2_change, train, family='binomial')
summary(noLight.log)
```

One interesting result is that the variables temp_change and CO2_change, that did not result as significant in the previous glm calls, do result significant now.

```{r}
test.noL <- predict(noLight.log, test, type = 'response')
test.noL <- rep(0, nrow(test))
test.noL[test.noL >= 0.5] <- 1
mean(test.noL == test$Occupancy)
```

The performance of the logistic function is quite satisfactory: the model makes the right call 81% of the time.
What is instead the behaviour on trees?

```{r}
noL.tree <- tree(Occupancy ~ Temperature + Humidity + CO2 + hum_change + CO2_change + temp_change + Day, train)
plot(noL.tree)
text(noL.tree, pretty=0)
```

As expected, the number of nodes in the tree has increased significantly.

```{r}
tree.pred <- predict(noL.tree, test, type="class")
mean(tree.pred==test$Occupancy)
```

The performance of our tree on test data is quite poor: the absence of the variable light decreases the accuracy of predictions by a significant amount. Let us now check whether including more trees (hence building a forest) has a positive effect on performance.

```{r}
forests <- data.frame(matrix(, nrow=, ncol=2))
names(forests) <- c("m", "Accuracy")
for(m in 1:6){
  rf.room <- randomForest(Occupancy~Temperature + Humidity + CO2 + hum_change + CO2_change + temp_change + Day, data=train , mtry=m, ntree=500)
  yhat.rf <- predict(rf.room, newdata=test)
  forests[m,] <- c(m, mean(yhat.rf==test$Occupancy))
}
forests
```

When testing a random forest, we see how the performance of our model significantly depends on how many predictors we build each tree with. Incredibly, it is better to make a random guess than to perform bagging. On the contrary, the performance of the forest is quite good when we build each tree with only one predictor.

### Clustering when room is occupied

```{r}
All <- rbind(train[train$Occupancy == 1,], test[test$Occupancy == 1,])
All <- All[-2702,]
PPCA <- prcomp(All[c(2,3,5, 8:11)], scale=T)
PPCA$rotation
HC <- hclust(dist(All[,c(2,3,5,8:11)]), method = "average")
plot(PPCA$x[,c(1,2)], col=cutree(HC,3))
```
