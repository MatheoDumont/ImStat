#include <opencv4/opencv2/core.hpp>
#include <opencv4/opencv2/highgui.hpp>
#include <iostream>
#include <random>
#include <cassert>
#include <set>
#include <cmath>
#include <chrono>
#include <string>

cv::Mat getGaussianKernel(int, int, double, double);

/*
A. Efros and T. Leung. Texture synthesis by non-parametric sampling. In Proceedings of the International
Conference on Computer Vision Volume 2, ICCV '99, pages 10331068, Washington, DC, USA, 1999.
IEEE Computer Society.
*/

#define im0 "data/synthese/text0.png"
#define im1 "data/synthese/text4.png"

// Taille de l'image synthetiser
int WIDTH = 100;
int HEIGHT = 100;

// Parametres de l'algorithme
// radius depuis le centre du patch, la taille est side_size(defini plus bas)
int WINDOW_RADIUS = 1;
// seuil autorisant le choix d'un patch plus ou moins eloigne sur meilleur(distance)
float EPSILON = 0.f;

int side_size = WINDOW_RADIUS * 2 + 1;

float sig = side_size / 6.4f;
static cv::Mat precomputed_gaussian = getGaussianKernel(side_size, side_size, sig, sig);

std::random_device seed;
std::default_random_engine rng(seed());
// std::default_random_engine rng(static_cast<long unsigned int>(time(0)));
std::uniform_real_distribution<float> u01(0.f, 1.f);

typedef std::pair<int, int> Cell;

// https://codereview.stackexchange.com/questions/169655/create-a-two-dimensional-gaussian-kernel
cv::Mat getGaussianKernel(int rows, int cols, double sigmax, double sigmay)
{
    const auto y_mid = (rows - 1) / 2.0;
    const auto x_mid = (cols - 1) / 2.0;

    const auto x_spread = 1. / (sigmax * sigmax * 2);
    const auto y_spread = 1. / (sigmay * sigmay * 2);

    const auto denominator = 8 * std::atan(1) * sigmax * sigmay;

    std::vector<double> gauss_x, gauss_y;

    gauss_x.reserve(cols);
    for (auto i = 0; i < cols; ++i)
    {
        auto x = i - x_mid;
        gauss_x.push_back(std::exp(-x * x * x_spread));
    }

    gauss_y.reserve(rows);
    for (auto i = 0; i < rows; ++i)
    {
        auto y = i - y_mid;
        gauss_y.push_back(std::exp(-y * y * y_spread));
    }

    cv::Mat kernel = cv::Mat::zeros(rows, cols, CV_32FC1);
    for (auto j = 0; j < rows; ++j)
        for (auto i = 0; i < cols; ++i)
        {
            kernel.at<float>(j, i) = gauss_x[i] * gauss_y[j] / denominator;
        }

    return kernel;
}

int sum_cell(const cv::Mat &mask, const Cell &c)
{
    int sum = 0;
    // donc masque de taille 3 de cote centre sur c
    for (int i = -1; i < 2; ++i)
        for (int j = -1; j < 2; ++j)
        {
            int row = i + c.first;
            int col = j + c.second;
            // if (row < 0 || row >= mask.rows || col < 0 || col >= mask.cols)
            //     continue;
            sum += mask.at<int32_t>(row, col);
        }

    return sum;
}

/*
 * On selectionne le Pixel a 0 ayant le plus de voisins a 1.
 */
Cell pick_max_pixel(const cv::Mat &mask)
{
    Cell c_max;
    int max_neighboorhood = 0;

    for (int i = WINDOW_RADIUS; i < mask.rows - WINDOW_RADIUS; ++i)
        for (int j = WINDOW_RADIUS; j < mask.cols - WINDOW_RADIUS; ++j)
        {
            // on ne compte pas les adjacences des pixels deja remplis
            if (mask.at<int32_t>(i, j) == 1)
                continue;

            Cell c = {i, j};

            int sum_neightboorhood_cell = sum_cell(mask, c);
            if (sum_neightboorhood_cell > max_neighboorhood)
            {
                c_max = c;
                max_neighboorhood = sum_neightboorhood_cell;
            }
        }

    return c_max;
}

float SSD_patch(const cv::Mat &Ismp, const cv::Mat &I, const cv::Mat &mask, Cell max_pixel, Cell c)
{
    float distance = 0.f;
    float sum_gauss = 0.f;

    for (int i = -WINDOW_RADIUS; i < WINDOW_RADIUS + 1; ++i)
        for (int j = -WINDOW_RADIUS; j < WINDOW_RADIUS + 1; ++j)
        {
            int row = i + max_pixel.first;
            int col = j + max_pixel.second;
            // if (row < 0 || row > mask.rows - 1 || col < 0 || col > mask.cols - 1)
            //     continue;

            // mask_gate in {0, 1}
            int mask_gate = mask.at<int32_t>(row, col);
            // if (mask.at<int32_t>(row, col) == 0)
            //     continue;

            int row_smp = i + c.first;
            int col_smp = j + c.second;
            // if (row_smp < 0 || row_smp > Ismp.rows - 1 || col_smp < 0 || col_smp > Ismp.cols - 1)
            //     continue;

            const cv::Vec3b &a = I.at<cv::Vec3b>(row, col);
            const cv::Vec3b &b = Ismp.at<cv::Vec3b>(row_smp, col_smp);

            float tmp_d = 0.f;
            float gauss = mask_gate * precomputed_gaussian.at<float>(i + WINDOW_RADIUS, j + WINDOW_RADIUS);
            sum_gauss += gauss;

            for (int i = 0; i < b.channels; ++i)
                tmp_d += std::pow(float(b[i]) - float(a[i]), 2);

            tmp_d *= gauss;
            distance += tmp_d;
        }
    return distance / sum_gauss;
}

struct Node
{
    float distance;
    Cell position;
    Node(float d, Cell p) : distance(d), position(p) {}
};

inline bool operator<(const Node &n1, const Node &n2)
{
    return n1.distance < n2.distance;
}

/*
 * Distance entre le patch centre sur max_pixel et tous les patch de cv::Mat Ismp
 */
std::set<Node> distance_to_patchs(const cv::Mat &Ismp, const cv::Mat &I, const cv::Mat &mask, const Cell &max_pixel)
{
    std::set<Node> nodes;

    for (int i = WINDOW_RADIUS; i < Ismp.rows - WINDOW_RADIUS; ++i)
        for (int j = WINDOW_RADIUS; j < Ismp.cols - WINDOW_RADIUS; ++j)
        {
            Cell c = {i, j};
            float distance = SSD_patch(Ismp, I, mask, max_pixel, c);
            nodes.insert(Node(distance, c));
        }

    return nodes;
}

float normalize01(float min, float max, float x)
{
    return (x - min) / (max - min);
}

std::vector<Node> pick_patchs_under_epsilon(const std::set<Node> &nodes)
{

    std::vector<Node> under_epsilon;
    auto ite_begin = nodes.begin();
    under_epsilon.push_back(*ite_begin);
    float best_distance = ite_begin->distance;
    float worst_distance = ((nodes.end())--)->distance;
    ite_begin++;
    float higher_bound = (1.f + EPSILON) * best_distance;

    for (auto ite = ite_begin;
         ite != nodes.end() && ite->distance <= higher_bound;
         ite++)
    {
        // if (ite->distance > higher_bound)
        //     break;

        under_epsilon.emplace_back(
            normalize01(best_distance, worst_distance, ite->distance),
            ite->position);
    }
    return under_epsilon;
}

cv::Mat compute(cv::Mat Ismp)
{
    int padding = WINDOW_RADIUS * 2;
    int padded_height = HEIGHT + padding;
    int padded_width = WIDTH + padding;
    cv::Mat I = cv::Mat::zeros(padded_height, padded_width, CV_8UC3);
    cv::Mat mask = cv::Mat_<int32_t>::zeros(padded_height, padded_width);

    std::cout << "I rows, col => "
              << "(" << mask.rows << ", " << mask.cols << ")" << std::endl;
    if ((side_size) >= Ismp.cols || (side_size) >= Ismp.rows)
    {
        // assert("WINDOW_RADIUS*2 cannot be > to the size of the input image" &&
        //        (WINDOW_RADIUS * 2) < Ismp.cols && (WINDOW_RADIUS * 2) < Ismp.rows);
        std::cout << "WINDOW_RADIUS*2 cannot be > to the size of the input image" << std::endl;
        exit(1);
    }

    { // on choisi un premier patch aleatoirement dans Ismp a coller au centre de I
        int row = u01(rng) * (Ismp.rows - WINDOW_RADIUS * 2) + WINDOW_RADIUS;
        int col = u01(rng) * (Ismp.cols - WINDOW_RADIUS * 2) + WINDOW_RADIUS;

        int row_out_centre = (I.rows + 1) / 2;
        int col_out_centre = (I.cols + 1) / 2;
        for (int i = -WINDOW_RADIUS; i < WINDOW_RADIUS + 1; ++i)
            for (int j = -WINDOW_RADIUS; j < WINDOW_RADIUS + 1; ++j)
            {
                I.at<cv::Vec3b>(row_out_centre + i, col_out_centre + j) = Ismp.at<cv::Vec3b>(row + i, col + j);
                mask.at<int32_t>(row_out_centre + i, col_out_centre + j) = 1;
            }
    }

    int pixel_to_be_filled = (HEIGHT * WIDTH) - (side_size * side_size);

    for (int i = 0; i < pixel_to_be_filled; ++i)
    {
        Cell max_pixel = pick_max_pixel(mask);
        Cell test_pixel = {max_pixel.first - WINDOW_RADIUS, max_pixel.second - WINDOW_RADIUS};

        if (test_pixel.first < 0 || test_pixel.first >= HEIGHT || test_pixel.second < 0 || test_pixel.second >= WIDTH)
        {
            std::cout << "max pixel en dehors de l'image" << std::endl;
            std::cout << max_pixel.first << ", " << max_pixel.second << std::endl;
            exit(1);
        }

        std::set<Node> nodes = distance_to_patchs(Ismp, I, mask, max_pixel);

        std::vector<Node> bests_under_epsilon = pick_patchs_under_epsilon(nodes);

        // on choisi aleatoirement parmis `bests_under_epsilon`
        int choice = (bests_under_epsilon.size() - 1) * u01(rng);

        // on met le pixel choisi
        Cell patch = bests_under_epsilon[choice].position;

        I.at<cv::Vec3b>(max_pixel.first, max_pixel.second) = Ismp.at<cv::Vec3b>(patch.first, patch.second);
        mask.at<int32_t>(max_pixel.first, max_pixel.second) = 1;
    }

    cv::Rect rect = cv::Rect(WINDOW_RADIUS, WINDOW_RADIUS, WIDTH, HEIGHT);
    cv::Mat cropped = cv::Mat(I, rect);
    return cropped;
    // return I;
}

int main()
{
    cv::Mat Ismp = cv::imread(im0);
    std::cout << Ismp.cols << ", " << Ismp.rows << std::endl;
    // cv::Mat imf;
    // Ismp.convertTo(imf, CV_32FC3);

    // std::cout << cv::typeToString(Ismp.type()) << std::endl;

    // std::cout << cv::typeToString(imf.type()) << std::endl;

    // cv::imshow("truc", Ismp);
    // cv::waitKey(0);
    auto cpu_start = std::chrono::high_resolution_clock::now();
    cv::Mat I = compute(Ismp);
    auto cpu_stop = std::chrono::high_resolution_clock::now();
    int cpu_time = std::chrono::duration_cast<std::chrono::milliseconds>(cpu_stop - cpu_start).count();
    printf("cpu  %ds %03dms\n", int(cpu_time / 1000), int(cpu_time % 1000));

    // cv::imshow("truc.jpg", I);
    // cv::waitKey(0);

    cv::imwrite("i.jpg", I);
}